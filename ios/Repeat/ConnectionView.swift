import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) var dismiss
    @State private var confirmingEnable = false
    @State private var confirmingDelete = false
    var body:some View {
        NavigationStack {
            Form {
                Section {
                    Label("Tus hábitos son tuyos",systemImage:"lock.icloud").font(.headline)
                    Text("Repeat funciona con los datos de este iPhone. Si eliges iCloud, tus hábitos se guardan en la base privada de tu cuenta de Apple, sin pasar por servidores de Repeat, OpenAI o Cloudflare.")
                }
                Section("iCloud opcional") {
                    if CloudSync.available {
                        if store.connected {
                            Button("Sincronizar ahora",systemImage:"arrow.clockwise") { Task { await store.sync(force:true) } }
                            Button("Desactivar sincronización",systemImage:"icloud.slash") { store.disableCloud() }
                        } else {
                            Button("Activar iCloud",systemImage:"icloud") { confirmingEnable = true }
                        }
                        if store.syncing { SwiftUI.ProgressView("Comprobando iCloud…") }
                        Text(store.syncText).font(.footnote).foregroundStyle(.secondary)
                        if let last = store.lastCloudSync {
                            LabeledContent("Última sincronización confirmada") { Text(last,format:.dateTime.day().month().hour().minute()) }
                        } else { Text("Todavía no hay una copia confirmada en iCloud.").font(.footnote) }
                        Text("\(store.state.queue.count) cambios pendientes").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Label("iCloud no disponible en esta instalación",systemImage:"icloud.slash")
                        Text("La firma de desarrollo gratuita de Apple no permite habilitar iCloud. Esta versión conserva tus datos en el iPhone; todavía no crea una copia en iCloud. Activarlo requiere una firma compatible de Apple Developer.").font(.footnote)
                        NavigationLink("Exportar una copia de mis hábitos") { BackupView() }
                    }
                }
                Section {
                    Text("La sincronización permite recuperar lo que ya llegó a iCloud si cambias de iPhone. Los cambios pendientes aún no están protegidos y los borrados también se sincronizan. No es un historial de copias de seguridad.")
                    Text("Las lecturas y correcciones de Apple Health permanecen en este iPhone y no forman parte de esta copia.")
                    Text("Las copias que existieran en la antigua aplicación web no se eliminan con esta actualización; se administran por separado.")
                }.font(.footnote).foregroundStyle(.secondary)
                if CloudSync.available {
                    Section {
                        Button("Eliminar la copia de iCloud",role:.destructive) { confirmingDelete = true }
                    } footer: { Text("Elimina la copia privada y desactiva la sincronización. Conserva los hábitos de este iPhone. No borra datos de la antigua web ni exportaciones que hayas guardado.") }
                }
            }
            .disabled(store.syncing)
            .navigationTitle("Privacidad e iCloud").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cerrar") { dismiss() } } }
            .confirmationDialog("Activar tu copia privada de iCloud",isPresented:$confirmingEnable,titleVisibility:.visible) {
                Button("Combinar y activar iCloud") { Task { await store.enableCloud() } }
                Button("Cancelar",role:.cancel) { }
            } message: { Text("Se combinarán los hábitos de este iPhone con la copia de tu cuenta de Apple. Si un registro coincide, se conservará el valor local al activar por primera vez. No se incluyen valores ni correcciones de Salud.") }
            .confirmationDialog("¿Eliminar la copia de iCloud?",isPresented:$confirmingDelete,titleVisibility:.visible) {
                Button("Eliminar de iCloud",role:.destructive) { Task { await store.deleteCloudCopy() } }
                Button("Cancelar",role:.cancel) { }
            } message: { Text("Se conservarán los datos de este iPhone. Otros dispositivos que usaban esta copia deberán revisarse antes de volver a sincronizar.") }
            .alert("iCloud",isPresented:Binding(get:{store.error != nil},set:{if !$0 { store.error = nil }})) { Button("Aceptar") { store.error = nil } } message: { Text(store.error ?? "") }
        }
    }
}
