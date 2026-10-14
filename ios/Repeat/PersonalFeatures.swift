import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers
import UIKit

struct AppLockCover: View {
    @Binding var unlocked:Bool
    @State private var message = ""
    var body:some View { VStack(spacing:22) { Image(systemName:"lock.shield").font(.system(size:55)).foregroundStyle(Color.repeatPink); Text("Tu espacio privado").font(.title2.weight(.semibold)); Button("Desbloquear Repeat") { unlock() }.buttonStyle(.borderedProminent); if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) } }.padding(30).frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(.systemBackground)).task { unlock() } }
    func unlock() { let context = LAContext(); context.localizedCancelTitle = "Cancelar"; Task { do { unlocked = try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Desbloquear tus hábitos en Repeat"); message = "" } catch { message = "Vuelve a intentarlo para abrir tu espacio." } } }
}
struct AppearanceView: View {
    @AppStorage("repeat.theme") private var theme = "system"
    @AppStorage("repeat.weekMode") private var weekMode = "week"
    @AppStorage("repeat.showStreaks") private var streaks = true
    var body:some View { Form { Section("Tema") { Picker("Apariencia",selection:$theme) { Text("Sistema").tag("system"); Text("Clara").tag("light"); Text("Oscura").tag("dark") }.pickerStyle(.inline) }; Section("Vista diaria") { Picker("Semana",selection:$weekMode) { Text("Esta semana").tag("week"); Text("Últimos siete días").tag("recent") }; Toggle("Mostrar rachas",isOn:$streaks) } }.navigationTitle("Apariencia") }
}
struct HabitManagerView: View {
    @EnvironmentObject var store:HabitStore
    @State private var edit:Habit? = nil
    @State private var deleting:Habit? = nil
    var habits:[Habit] { store.state.snapshot.habits.sorted{$0.order < $1.order} }
    var body:some View { List { ForEach(habits) { h in HStack { Text(h.icon).font(.title2); VStack(alignment:.leading,spacing:4) { Text(h.name); Text(h.archived ? "Archivado" : h.goalLabel).font(.caption).foregroundStyle(.secondary) }; Spacer(); Menu { Button("Editar",systemImage:"pencil") { edit = h }; Button("Duplicar",systemImage:"doc.on.doc") { store.duplicate(h) }; Button(h.archived ? "Recuperar" : "Archivar",systemImage:h.archived ? "tray.and.arrow.up" : "archivebox") { store.mutate(Operation(op:"archive",id:h.id,archived:!h.archived)) }; Button("Eliminar",systemImage:"trash",role:.destructive) { deleting = h } } label: { Image(systemName:"ellipsis").padding(8) }.disabled(store.focus?.habitId == h.id) }.swipeActions { Button(role:.destructive) { deleting = h } label: { Label("Eliminar",systemImage:"trash") }.disabled(store.focus?.habitId == h.id); Button { store.mutate(Operation(op:"archive",id:h.id,archived:!h.archived)) } label: { Label(h.archived ? "Recuperar" : "Archivar",systemImage:"archivebox") }.tint(.orange).disabled(store.focus?.habitId == h.id) } }.onMove { offsets,index in var order = habits.map(\.id); order.move(fromOffsets:offsets,toOffset:index); store.reorder(order) } }.navigationTitle("Gestionar hábitos").toolbar { EditButton() }.sheet(item:$edit) { HabitEditor(initial:$0) }.confirmationDialog("Eliminar este hábito y sus registros",isPresented:Binding(get:{deleting != nil},set:{if !$0 { deleting = nil }}),titleVisibility:.visible) { Button("Eliminar definitivamente",role:.destructive) { if let deleting { store.delete(deleting) }; deleting = nil }; Button("Cancelar",role:.cancel) { deleting = nil } } message: { Text("Esta acción no se puede deshacer. Puedes archivar el hábito para conservar su historial.") } }
}
struct GroupManagerView: View {
    @EnvironmentObject var store:HabitStore
    @State private var selected:String? = nil
    @State private var name = ""
    var body:some View { List { ForEach(store.groups,id:\.self) { g in Button { selected = g; name = g } label: { HStack { Text(g); Spacer(); Text("\(store.active.filter{$0.group == g}.count)").foregroundStyle(.secondary); Image(systemName:"pencil") } } } }.navigationTitle("Gestionar grupos").alert("Nombre del grupo",isPresented:Binding(get:{selected != nil},set:{if !$0 { selected = nil }})) { TextField("Nombre",text:$name); Button("Guardar") { if let selected { store.renameGroup(selected,to:name) }; selected = nil }; Button("Cancelar",role:.cancel) { selected = nil } } message: { Text("Un nombre vacío retira el grupo y conserva sus hábitos.") } }
}
struct BackupView: View {
    @EnvironmentObject var store:HabitStore
    @State private var importing = false
    @State private var candidate:Snapshot? = nil
    @State private var importError:String? = nil
    @State private var exported:URL? = nil
    @State private var success = false
    var body:some View {
        Form {
            Section { Button("Exportar copia JSON",systemImage:"square.and.arrow.up") { exportJSON() }; Button("Restaurar desde una copia",systemImage:"square.and.arrow.down") { importing = true } } header: { Text("Copia de seguridad") } footer: { Text("La restauración combina los datos. Los registros con el mismo identificador se actualizan; los demás se conservan. Los valores de Apple Health no se exportan.") }
            Section("Registros") { Button("Exportar CSV",systemImage:"tablecells") { exportCSV() } }
            if success { Section { Label("Copia restaurada y guardada en el iPhone",systemImage:"checkmark.circle.fill").foregroundStyle(.green) } }
        }.navigationTitle("Copia y exportación")
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in do { let url = try result.get(); let allowed = url.startAccessingSecurityScopedResource(); defer { if allowed { url.stopAccessingSecurityScopedResource() } }; let values = try url.resourceValues(forKeys:[.fileSizeKey]); guard (values.fileSize ?? 0) <= 10_000_000 else { throw BackupError.invalid("La copia supera 10 MB.") }; candidate = try readBackup(Data(contentsOf:url)) } catch { importError = error.localizedDescription } }
        .confirmationDialog("Restaurar copia",isPresented:Binding(get:{candidate != nil},set:{if !$0 { candidate = nil }}),titleVisibility:.visible) { Button("Combinar y restaurar") { if let candidate { store.restore(candidate); success = true }; candidate = nil }; Button("Cancelar",role:.cancel) { candidate = nil } } message: { Text("\(candidate?.habits.count ?? 0) hábitos y \(candidate?.entries.count ?? 0) registros. Se conservarán los datos que no estén en esta copia.") }
        .alert("No se pudo importar",isPresented:Binding(get:{importError != nil},set:{if !$0 { importError = nil }})) { Button("Aceptar") {} } message: { Text(importError ?? "") }
        .sheet(item:Binding(get:{exported.map{SharedFile(url:$0)}},set:{exported = $0?.url})) { file in ShareSheet(items:[file.url]) }
    }
    func exportJSON() { do { let url = URL.temporaryDirectory.appending(path:"repeat-\(Day.key(Date())).json"); try JSONEncoder().encode(store.state.snapshot).write(to:url,options:.atomic); exported = url } catch { importError = error.localizedDescription } }
    func exportCSV() {
        func cell(_ value:String) -> String { let safe = value.first.map{ "=+-@".contains($0) } == true ? "'"+value : value; return "\""+safe.replacingOccurrences(of:"\"",with:"\"\"")+"\"" }
        var rows = [["Fecha","Hábito","Valor","Unidad","Confirmado","Nota"]]
        for e in store.state.snapshot.entries.sorted(by:{$0.date < $1.date}) { let h = store.state.snapshot.habits.first{$0.id == e.habitId}; rows.append([e.date,h?.name ?? "",String(e.value),h?.at(e.date).unit ?? "",e.checked ? "Sí" : "No",e.note]) }
        let text = "\u{FEFF}"+rows.map{$0.map(cell).joined(separator:",")}.joined(separator:"\r\n")
        do { let url = URL.temporaryDirectory.appending(path:"repeat-registros-\(Day.key(Date())).csv"); try Data(text.utf8).write(to:url,options:.atomic); exported = url } catch { importError = error.localizedDescription }
    }
}
struct SharedFile:Identifiable { var url:URL; var id:String { url.absoluteString } }
struct ShareSheet:UIViewControllerRepresentable { var items:[Any]; func makeUIViewController(context:Context) -> UIActivityViewController { UIActivityViewController(activityItems:items,applicationActivities:nil) }; func updateUIViewController(_ uiViewController:UIActivityViewController,context:Context) {} }
struct HealthSettingsView: View {
    @EnvironmentObject var store:HabitStore
    var body:some View { Form { Section { Text("Conecta un dato al crear o editar un hábito. El iPhone lee únicamente los tipos que seleccionas y iOS controla los permisos.").font(.footnote).foregroundStyle(.secondary); Button(store.readingHealth ? "Actualizando…" : "Actualizar datos de Salud") { Task { await store.refreshHealth() } }.disabled(store.readingHealth) }; Section("Hábitos conectados") { ForEach(store.active.filter{store.healthSource($0.id) != nil}) { h in HStack { Text(h.icon); Text(h.name); Spacer(); Text(store.healthSource(h.id)?.title ?? "").font(.caption).foregroundStyle(.secondary) } } }; Section { Toggle("Mostrar Salud en widgets",isOn:Binding(get:{store.healthConfiguration.showOnWidgets},set:{store.healthConfiguration.showOnWidgets = $0; store.saveHealth()})) } footer: { Text("Los datos de Salud se guardan solo en este dispositivo. Esta opción permite mostrar los valores en tus widgets, también locales.") } }.navigationTitle("Apple Health") }
}
struct DailyQuoteView: View {
    @AppStorage("repeat.personalQuote") private var personal = ""
    static let quotes = ["Un pequeño paso también es progreso.","Tu ritmo también cuenta.","Hoy puedes volver a empezar.","La constancia se construye un día a la vez.","Haz espacio para lo que te importa.","No hace falta hacerlo perfecto para seguir avanzando.","Celebra lo que sí hiciste hoy."]
    var body:some View { Form { Section("Tu frase") { TextField("Escribe una frase para ti",text:$personal,axis:.vertical).lineLimit(3...6) }; Section("Para hoy") { Text(personal.isEmpty ? Self.quotes[Calendar.current.ordinality(of:.day,in:.year,for:Date())! % Self.quotes.count] : personal).font(.title3).padding(.vertical,20) } }.navigationTitle("Frase diaria") }
}
