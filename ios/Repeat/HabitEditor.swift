import SwiftUI
import UserNotifications

struct HabitEditor: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) var dismiss
    @State private var draft: Habit
    @State private var goalText: String
    @State private var reminderTimes: [Date]
    @State private var validation: String? = nil
    @State private var healthEnabled = false
    @State private var healthSourceID = "steps"
    @State private var authorizing = false
    @State private var initializedHealth = false
    @State private var superAlert = false
    @State private var metricEffectiveDate = Day.key(Date())
    let suggestedHealth:String?
    let isNew:Bool
    let draftKey:String
    let onSaved:((Habit)->Void)?
    var draftState:EditorDraft { EditorDraft(habit:draft,goalText:goalText,reminderTimes:reminderTimes,healthEnabled:healthEnabled,healthSourceID:healthSourceID,superAlert:superAlert,metricEffectiveDate:metricEffectiveDate) }
    init(initial: Habit,suggestedHealth:String? = nil,isNew:Bool = false,onSaved:((Habit)->Void)? = nil) {
        self.isNew = isNew; self.draftKey = initial.id; self.onSaved = onSaved
        self.suggestedHealth = suggestedHealth
        let recovered = EditorDraft.read(isNew:isNew,id:initial.id)
        _draft = State(initialValue:recovered?.habit ?? initial); _goalText = State(initialValue:recovered?.goalText ?? String(initial.goal))
        _healthEnabled = State(initialValue:recovered?.healthEnabled ?? (suggestedHealth != nil)); _healthSourceID = State(initialValue:recovered?.healthSourceID ?? suggestedHealth ?? "steps")
        _superAlert = State(initialValue:recovered?.superAlert ?? UserDefaults.standard.bool(forKey:"repeat.superAlert."+initial.id))
        _initializedHealth = State(initialValue:recovered != nil)
        _metricEffectiveDate = State(initialValue:max(Day.key(Date()),recovered?.metricEffectiveDate ?? Day.key(Date())))
        _reminderTimes = State(initialValue:recovered?.reminderTimes ?? initial.reminders.compactMap { value in let parts = value.split(separator:":").compactMap { Int($0) }; guard parts.count == 2 else { return nil }; return Calendar.current.date(bySettingHour:parts[0],minute:parts[1],second:0,of:Date()) })
    }
    let palette = ["#FF5B86","#5CBAF0","#3BD6BE","#8D71E1","#F4B357","#EC88B5","#7895E0","#8FC77D","#7D8796","#D4A37C","#76C8D0","#F4756A"]
    let frequencyNames = [("daily","Todos los días"),("weekdays","Días de la semana"),("week-count","Días por semana"),("monthdays","Días del mes"),("month-count","Días por mes"),("cycle-days","Días de cada ciclo"),("cycle-count","Días por ciclo")]
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing:17) {
                        NavigationLink { IconChooser(icon:$draft.icon) } label: { Text(draft.icon).font(.system(size:40)).frame(width:56,height:60) }.fixedSize()
                        VStack { TextField("Nombre del hábito",text:$draft.name); Divider(); TextField("Descripción (opcional)",text:$draft.description).font(.subheadline) }
                    }
                    NavigationLink { colorChooser } label: { HStack { Text("Color"); Spacer(); Capsule().fill(draft.tint).frame(width:48,height:22) } }
                    NavigationLink { GroupChooser(group:$draft.group,groups:store.groups) } label: { HStack { Text("Grupo"); Spacer(); Text(draft.group.isEmpty ? "Opcional" : draft.group).foregroundStyle(.secondary) } }
                }
                Section { Picker("Tipo de hábito",selection:$draft.type) { Text("Construir").tag("build"); Text("Dejar").tag("quit") } }
                Section {
                    Toggle("Apple Health",isOn:$healthEnabled)
                    if healthEnabled { Picker("Dato de Salud",selection:$healthSourceID) { ForEach(HealthSource.all) { source in Text(source.title).tag(source.id) } }; Text("Los valores de Salud permanecen en el iPhone y no se envían a la web.").font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    Picker("Periodo de la meta",selection:$draft.period) { Text("Todo el día").tag("day"); Text("Una semana").tag("week"); Text("Un mes").tag("month"); Text("Personalizado").tag("custom") }
                    if draft.period == "custom" { Stepper("Cada \(draft.periodDays) días",value:$draft.periodDays,in:1...365) }
                    NavigationLink { goalChooser } label: { HStack { Text("Valor de la meta"); Spacer(); Text("\(goalText) \(draft.unit)").foregroundStyle(.secondary) } }
                    NavigationLink { frequencyChooser } label: { HStack { Text("Días del hábito"); Spacer(); Text(frequencyNames.first{$0.0 == draft.frequency}?.1 ?? "Todos los días").font(.subheadline).foregroundStyle(.secondary) } }
                } footer: { Text(draft.type == "quit" ? "Registra el consumo y confirma que no superaste tu límite." : "Completa tu meta en el periodo elegido.") }
                if !isNew { Section {
                    DatePicker("Aplicar cambios de meta desde",selection:Binding(get:{Day.date(metricEffectiveDate)},set:{metricEffectiveDate = Day.key($0)}),in:Calendar.current.startOfDay(for:Date())...,displayedComponents:.date)
                } footer: { Text("La meta, unidad y frecuencia anteriores se conservan para las fechas pasadas.") } }
                Section("Franja horaria") { Picker("Horario",selection:$draft.timeOfDay) { Text("Cualquiera").tag("any"); Text("Mañana").tag("morning"); Text("Tarde").tag("afternoon"); Text("Noche").tag("evening") }.pickerStyle(.segmented) }
                Section {
                    Toggle("Recordatorios",isOn:Binding(get:{!reminderTimes.isEmpty},set:{ enabled in reminderTimes = enabled ? [Calendar.current.date(bySettingHour:9,minute:0,second:0,of:Date())!] : [] }))
                    if !reminderTimes.isEmpty { Toggle("Alerta reforzada",isOn:$superAlert); if superAlert { Text("Repite el aviso a los 5, 10 y 15 minutos. Esta opción se guarda en este iPhone.").font(.caption).foregroundStyle(.secondary) } }
                    ForEach(reminderTimes.indices,id:\.self) { i in HStack { DatePicker("Aviso \(i+1)",selection:$reminderTimes[i],displayedComponents:.hourAndMinute); Button(role:.destructive) { reminderTimes.remove(at:i) } label: { Image(systemName:"minus.circle") }.buttonStyle(.borderless) } }
                    if reminderTimes.count < 10 { Button { reminderTimes.append(Calendar.current.date(bySettingHour:9,minute:0,second:0,of:Date())!) } label: { Label("Añadir recordatorio",systemImage:"plus") } }
                    Toggle("Abrir nota al completar",isOn:$draft.memoAfter)
                } header: { Text("Recordatorios") } footer: { Text("Los recordatorios nativos pueden avisarte con la app cerrada. iOS te pedirá permiso al guardar el primer aviso.") }
                Section {
                    DatePicker("Fecha de inicio",selection:Binding(get:{Day.date(draft.startDate)},set:{draft.startDate = Day.key($0)}),displayedComponents:.date)
                    Toggle("Fecha de finalización",isOn:Binding(get:{draft.endDate != nil},set:{draft.endDate = $0 ? max(draft.startDate,Day.key(Date())) : nil}))
                    if let end = draft.endDate { DatePicker("Terminar el",selection:Binding(get:{Day.date(end)},set:{draft.endDate = Day.key($0)}),in:Day.date(draft.startDate)...,displayedComponents:.date) }
                }
            }.disabled(authorizing).scrollContentBackground(.hidden).background(draft.tint.opacity(0.07)).navigationTitle("\(draft.icon) \(draft.name.isEmpty ? "Hábito personalizado" : draft.name)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.principal) { Text("\(draft.icon) \(draft.name.isEmpty ? "Personalizado" : draft.name)").font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7) }; ToolbarItem(placement:.cancellationAction) { Button("Cancelar") { preserveDraft(); dismiss() }.disabled(authorizing) }; ToolbarItem(placement:.confirmationAction) { Button(authorizing ? "Guardando…" : isNew ? "Crear" : "Guardar") { save() }.fontWeight(.semibold).disabled(authorizing) } }
            .onAppear { guard !initializedHealth else { return }; initializedHealth = true; superAlert = UserDefaults.standard.bool(forKey:"repeat.superAlert."+draft.id); if let source = store.healthConfiguration.sources[draft.id] ?? suggestedHealth { healthEnabled = true; healthSourceID = source; if let data = HealthSource.all.first(where:{$0.id == source}) { draft.unit = data.unit } } }
            .interactiveDismissDisabled(authorizing)
            .onChange(of:draftState) { _,_ in preserveDraft() }
            .onDisappear { if !saved { preserveDraft() } }
            .onChange(of:healthSourceID) { _,id in if healthEnabled,let source = HealthSource.all.first(where:{$0.id == id}) { draft.unit = source.unit } }
            .alert("Revisa tu hábito",isPresented:Binding(get:{validation != nil},set:{if !$0 { validation = nil }})) { Button("Aceptar") {} } message: { Text(validation ?? "") }
        }
    }
    var colorChooser: some View {
        ScrollView { ColorPicker("Color personalizado",selection:Binding(get:{draft.tint},set:{ value in let color = UIColor(value); var r:CGFloat = 0,g:CGFloat = 0,b:CGFloat = 0,a:CGFloat = 0; color.getRed(&r,green:&g,blue:&b,alpha:&a); draft.color = String(format:"#%02X%02X%02X",Int(r*255),Int(g*255),Int(b*255)) }),supportsOpacity:false).padding(); LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:4),spacing:26) { ForEach(palette,id:\.self) { hex in Button { draft.color = hex } label: { Circle().fill(Color(hex:hex)).frame(width:60,height:60).overlay { if draft.color == hex { Image(systemName:"checkmark").foregroundStyle(.white) } } }.accessibilityLabel("Color \(hex)") } }.padding(30) }.navigationTitle("Color")
    }
    var goalChooser: some View {
        Form {
            HStack { Text(draft.type == "quit" ? "Límite máximo" : "Valor de la meta"); Spacer(); TextField("Valor",text:$goalText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            Picker("Unidad",selection:$draft.unit) { ForEach(["","veces","pasos","m","km","millas","ml","oz","Cal","g","mg","vasos","páginas","sec","min","hr"],id:\.self) { u in Text(u.isEmpty ? "Sin unidad" : u).tag(u) } }
            TextField("Unidad personalizada",text:$draft.unit)
            Section { Text("Las unidades sec, min y hr habilitan el temporizador.").foregroundStyle(.secondary) }
        }.navigationTitle("Valor de la meta").navigationBarTitleDisplayMode(.inline)
    }
    var frequencyChooser: some View {
        Form {
            Picker("Frecuencia",selection:$draft.frequency) { ForEach(frequencyNames,id:\.0) { key,name in Text(name).tag(key) } }.pickerStyle(.inline)
            if draft.frequency.contains("cycle") { Stepper("Ciclo de \(draft.cycleDays) días",value:$draft.cycleDays,in:1...365) }
            if draft.frequency == "weekdays" { daySelector(count:7,labels:["L","M","X","J","V","S","D"]) }
            if draft.frequency == "monthdays" || draft.frequency == "cycle-days" { daySelector(count:draft.frequency == "monthdays" ? 31 : draft.cycleDays,labels:nil) }
            if draft.frequency.hasSuffix("count") { Stepper("Completar \(draft.targetDays) días",value:$draft.targetDays,in:1...max(1,draft.frequency == "week-count" ? 7 : draft.frequency == "month-count" ? 31 : draft.cycleDays)) }
        }.navigationTitle("Días del hábito").navigationBarTitleDisplayMode(.inline)
        .onChange(of:draft.frequency) { _,f in draft.days = f == "weekdays" ? [1,2,3,4,5] : [1]; draft.targetDays = min(draft.targetDays,f == "week-count" ? 7 : f == "month-count" ? 31 : draft.cycleDays) }
    }
    func daySelector(count:Int,labels:[String]?) -> some View {
        LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:7),spacing:12) { ForEach(1...max(1,count),id:\.self) { n in Button { if draft.days.contains(n) { draft.days.removeAll{$0 == n} } else { draft.days.append(n) } } label: { Text(labels?[n-1] ?? "\(n)").font(.caption).frame(width:30,height:30).foregroundStyle(draft.days.contains(n) ? Color.white : Color.primary).background(draft.days.contains(n) ? Color.repeatPink : Color(.tertiarySystemFill),in:Circle()) }.buttonStyle(.plain) } }.padding(.vertical,12)
    }
    func save() {
        draft.name = draft.name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !draft.name.isEmpty,draft.name.utf16.count <= 100 else { validation = "Escribe un nombre de hasta 100 caracteres."; return }
        guard let goal = Double(goalText.replacingOccurrences(of:",",with:".")),goal.isFinite,goal >= (draft.type == "quit" ? 0 : 0.001),goal <= 1e9 else { validation = "Escribe una meta válida."; return }
        if ["weekdays","monthdays","cycle-days"].contains(draft.frequency) && draft.days.isEmpty { validation = "Selecciona al menos un día."; return }
        if let end = draft.endDate,end < draft.startDate { validation = "La fecha final debe ser posterior al inicio."; return }
        draft.goal = goal; draft.description = limitedText(draft.description,300); draft.group = limitedText(draft.group,60); draft.unit = limitedText(draft.unit,30); draft.icon = limitedText(draft.icon,24);
        let maxDay = draft.frequency == "weekdays" ? 7 : draft.frequency == "monthdays" ? 31 : draft.cycleDays
        if ["weekdays","monthdays","cycle-days"].contains(draft.frequency) { draft.days = draft.days.filter{$0 <= maxDay}; if draft.days.isEmpty { validation = "Selecciona días dentro del ciclo."; return } }
        draft.targetDays = min(draft.targetDays,draft.frequency == "week-count" ? 7 : draft.frequency == "month-count" ? 31 : draft.cycleDays)
        draft.reminders = reminderTimes.map { let c = Calendar.current.dateComponents([.hour,.minute],from:$0); return String(format:"%02d:%02d",c.hour!,c.minute!) }
        if healthEnabled,let source = HealthSource.all.first(where:{$0.id == healthSourceID}) { draft.unit = source.unit; authorizing = true; Task { do { try await store.health.request(source); commit() } catch { validation = error.localizedDescription; authorizing = false } }; return }
        commit()
    }
    @State private var saved = false
    func preserveDraft() { do { try draftState.write(isNew:isNew,id:draftKey) } catch { validation = "No se pudo conservar el borrador: \(error.localizedDescription)" } }
    func commit() {
        preserveDraft()
        guard store.storeHabit(draft,effectiveDate:metricEffectiveDate) else { validation = store.error ?? "No se pudo guardar. Tu personalización sigue en este formulario."; store.error = nil; authorizing = false; return }
        UserDefaults.standard.set(superAlert,forKey:"repeat.superAlert."+draft.id); store.configureHealth(draft,source:healthEnabled ? healthSourceID : nil)
        if !draft.reminders.isEmpty { Task { let center = UNUserNotificationCenter.current(); let s = await center.notificationSettings(); if s.authorizationStatus == .notDetermined { _ = try? await center.requestAuthorization(options:[.alert,.sound,.badge]) }; await store.scheduleReminders() } }
        saved = true; EditorDraft.clear(isNew:isNew,id:draftKey); onSaved?(draft); dismiss()
    }
}
struct IconChooser: View {
    @Binding var icon: String
    let icons = ["⭐","🙏","📚","🧘","💧","🏃","💪","🚶","🛏️","🥗","🍎","🧠","🎨","🎹","🌱","☀️","📝","🦷","🏠","💻","💰","❤️","📵","🚭","☕","🐶","🎯","✨","🧹","🚴","🏊","🗣️"]
    var body: some View { ScrollView { LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:5),spacing:15) { ForEach(icons,id:\.self) { e in Button { icon = e } label: { Text(e).font(.system(size:34)).frame(width:53,height:60).background(icon == e ? Color.repeatPink.opacity(0.12) : .clear,in:RoundedRectangle(cornerRadius:13)) } } }.padding(); TextField("Tu emoji",text:$icon).textFieldStyle(.roundedBorder).padding() }.navigationTitle("Icono") }
}
struct GroupChooser: View {
    @Binding var group: String; var groups: [String]
    var body: some View { Form { TextField("Nombre del grupo",text:$group); Button("Sin grupo") { group = "" }; ForEach(groups,id:\.self) { g in Button(g) { group = g } } }.navigationTitle("Grupo") }
}
