import Foundation
import CloudKit

struct CloudExchange { var snapshot:Snapshot; var link:CloudLink }
enum CloudSyncError: LocalizedError {
    case unavailable, noAccount, accountChanged, copyRemoved, invalidCopy, tooLarge, conflict
    var errorDescription:String? {
        switch self {
        case .unavailable: return "Esta instalación de desarrollo no tiene habilitada la capacidad iCloud. Activarla requiere una firma compatible de Apple Developer. Tus hábitos siguen guardados en este iPhone; puedes exportar una copia desde Copia y exportación."
        case .noAccount: return "Inicia sesión en iCloud en Ajustes del iPhone para usar tu copia privada."
        case .accountChanged: return "La cuenta de iCloud cambió. Repeat ha detenido la sincronización para no mezclar tus hábitos con otra cuenta. Conserva una exportación antes de cambiar de cuenta."
        case .copyRemoved: return "La copia de iCloud se eliminó o se reemplazó desde otro dispositivo. La sincronización se ha detenido para no volver a subir datos eliminados. Tus hábitos locales se conservan."
        case .invalidCopy: return "No se pudo validar la copia de iCloud. Los datos de este iPhone no se han reemplazado."
        case .tooLarge: return "La copia supera el tamaño admitido por esta versión de la sincronización. Tus datos locales se conservan; exporta una copia y actualiza Repeat."
        case .conflict: return "Otro dispositivo está actualizando la copia. Espera un momento y vuelve a sincronizar."
        }
    }
}

@MainActor final class CloudSync {
    static var available:Bool {
        #if REPEAT_ICLOUD
        return true
        #else
        return false
        #endif
    }
    private let zoneID = CKRecordZone.ID(zoneName:"RepeatPrivate",ownerName:CKCurrentUserDefaultName)
    // A custom zone allows atomic compare-and-swap of the manifest and encrypted
    // chunks. Chunking keeps habits unlimited rather than imposing a record limit
    // on the user's whole snapshot. Server quota errors leave the local queue intact.
    private let chunkSize = 128 * 1024
    private let maximumChunks = 180
    private var container:CKContainer {
        CKContainer(identifier:"iCloud.com.adrianruiz.repeat")
    }
    private func account() async throws -> String {
        guard Self.available else { throw CloudSyncError.unavailable }
        guard try await container.accountStatus() == .available else { throw CloudSyncError.noAccount }
        return try await container.userRecordID().recordName
    }
    private func verifyAccount(_ link:CloudLink?,_ accountID:String) throws {
        if let link,link.accountID != accountID { throw CloudSyncError.accountChanged }
    }
    private func fetch(_ database:CKDatabase,_ id:CKRecord.ID) async throws -> CKRecord? {
        do { return try await database.record(for:id) }
        catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound { return nil }
    }
    func exchange(_ local:SavedState) async throws -> CloudExchange {
        let accountID = try await account()
        try verifyAccount(local.cloud,accountID)
        let database = container.privateCloudDatabase
        let manifestID = CKRecord.ID(recordName:"current",zoneID:zoneID)
        for _ in 0..<3 {
            do {
                let manifest = try await fetch(database,manifestID)
                if manifest == nil,local.cloud != nil { throw CloudSyncError.copyRemoved }
                if manifest == nil { _ = try await database.save(CKRecordZone(zoneID:zoneID)) }
                var replica = CloudReplica()
                let oldNames:[String]
                if let manifest {
                    guard let names = manifest["chunks"] as? [String],!names.isEmpty,names.count <= maximumChunks else { throw CloudSyncError.invalidCopy }
                    oldNames = names
                    var data = Data()
                    for name in names {
                        guard let record = try await fetch(database,CKRecord.ID(recordName:name,zoneID:zoneID)),
                              let part = record.encryptedValues["payload"] as? Data else { throw CloudSyncError.conflict }
                        data.append(part)
                    }
                    guard let decoded = try? JSONDecoder().decode(CloudReplica.self,from:data),decoded.version == 1 else { throw CloudSyncError.invalidCopy }
                    replica = decoded
                    _ = try readBackup(JSONEncoder().encode(replica.snapshot))
                    if let link = local.cloud,link.epoch != replica.epoch { throw CloudSyncError.copyRemoved }
                } else { oldNames = [] }
                replica.incorporate(local)
                // Validate before upload as well; future schema versions cannot
                // silently strip metric histories or replace an unreadable copy.
                _ = try readBackup(JSONEncoder().encode(replica.snapshot))
                let payload = try JSONEncoder().encode(replica)
                let count = max(1,(payload.count + chunkSize - 1) / chunkSize)
                guard count <= maximumChunks else { throw CloudSyncError.tooLarge }
                let generation = UUID().uuidString.lowercased()
                var records:[CKRecord] = []
                for index in 0..<count {
                    let record = CKRecord(recordType:"RepeatEncryptedChunk",recordID:CKRecord.ID(recordName:generation+"-"+String(index),zoneID:zoneID))
                    let start = index * chunkSize,end = min(payload.count,start + chunkSize)
                    record.encryptedValues["payload"] = payload.subdata(in:start..<end) as NSData
                    records.append(record)
                }
                let head = manifest ?? CKRecord(recordType:"RepeatManifest",recordID:manifestID)
                head["chunks"] = records.map { $0.recordID.recordName } as NSArray
                records.append(head)
                // Check again before writing if the Apple account changed mid-flight.
                guard try await account() == accountID else { throw CloudSyncError.accountChanged }
                let result = try await database.modifyRecords(saving:records,deleting:oldNames.map{CKRecord.ID(recordName:$0,zoneID:zoneID)},savePolicy:.ifServerRecordUnchanged,atomically:true)
                for (_,saved) in result.saveResults { _ = try saved.get() }
                for (_,deleted) in result.deleteResults { _ = try deleted.get() }
                return CloudExchange(snapshot:replica.snapshot,link:CloudLink(accountID:accountID,epoch:replica.epoch,lastSync:Date()))
            } catch let error as CKError where error.code == .serverRecordChanged || error.code == .batchRequestFailed || error.code == .unknownItem {
                continue
            } catch CloudSyncError.conflict { continue }
        }
        throw CloudSyncError.conflict
    }
    func deleteCopy(link:CloudLink?) async throws {
        let accountID = try await account()
        try verifyAccount(link,accountID)
        do { _ = try await container.privateCloudDatabase.deleteRecordZone(withID:zoneID) }
        catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem { return }
    }
    static func message(for error:Error) -> String {
        if let known = error as? CloudSyncError { return known.localizedDescription }
        if let cloud = error as? CKError {
            switch cloud.code {
            case .notAuthenticated: return CloudSyncError.noAccount.localizedDescription
            case .networkUnavailable,.networkFailure,.serviceUnavailable,.requestRateLimited:
                return "iCloud no está disponible ahora. Tus cambios siguen guardados en el iPhone. Vuelve a intentarlo con conexión."
            case .quotaExceeded: return "No hay espacio suficiente en tu iCloud. Tus cambios siguen en el iPhone; libera espacio o exporta una copia."
            case .permissionFailure,.missingEntitlement,.badContainer:
                return "Esta instalación no puede acceder al contenedor privado de iCloud. Tus datos siguen en el iPhone."
            default: break
            }
        }
        return "No se pudo confirmar la copia en iCloud. Tus datos locales y los cambios pendientes se conservan."
    }
}
