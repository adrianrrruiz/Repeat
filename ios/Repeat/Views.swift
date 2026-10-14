import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: HabitStore
    @State private var tab = 0
    @State private var group = ""
    @AppStorage("repeat.theme") private var theme = "system"
    @AppStorage("repeat.lockEnabled") private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var deepLinkHabit:Habit? = nil
    @State private var deepLinkDate = Day.key(Date())
    private let tick = Timer.publish(every:15,on:.main,in:.common).autoconnect()
    var body: some View {
        TabView(selection:$tab) {
            TodayView(group:$group).tabItem { Image(systemName:"house.fill").accessibilityLabel("Hoy") }.tag(0)
            OverviewView().tabItem { Image(systemName:"chart.bar.fill").accessibilityLabel("Progreso") }.tag(1)
            GroupsView { selected in group = selected; tab = 0 }.tabItem { Image(systemName:"folder.fill").accessibilityLabel("Grupos") }.tag(2)
            ReportsView().tabItem { Image(systemName:"list.bullet.clipboard.fill").accessibilityLabel("Informes") }.tag(3)
            SettingsView().tabItem { Image(systemName:"gearshape.fill").accessibilityLabel("Mi espacio") }.tag(4)
        }
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .accessibilityHidden(lockEnabled && !unlocked)
        .overlay { if lockEnabled && !unlocked { AppLockCover(unlocked:$unlocked) } }
        .onChange(of:scenePhase) { _,phase in if phase != .active && lockEnabled { unlocked = false } }
        .onChange(of:lockEnabled) { _,enabled in if enabled { unlocked = false }; store.publishWidget() }
        .sheet(item:$deepLinkHabit) { HabitDetail(original:$0,date:deepLinkDate) }
        .onOpenURL { url in guard url.scheme == "repeat" else { return }; tab = 0; let params = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems ?? []; if let id = params.first(where:{$0.name == "id"})?.value,let h = store.active.first(where:{$0.id == id}) { deepLinkDate = Day.key(Date()); deepLinkHabit = h } }
        .onReceive(tick) { _ in if store.connected { Task { await store.sync() } } }
        .alert("Repeat",isPresented:Binding(get:{store.error != nil},set:{if !$0 { store.error = nil }})) { Button("Aceptar") { store.error = nil } } message: { Text(store.error ?? "") }
    }
}
struct ProgressRing: View {
    var ratio: Double; var color: Color = .repeatPink; var size: CGFloat = 40
    var body: some View { ZStack { Circle().stroke(color.opacity(0.13),lineWidth:size > 100 ? 12 : 2.5); Circle().trim(from:0,to:min(1,max(0,ratio))).stroke(color,style:StrokeStyle(lineWidth:size > 100 ? 12 : 2.5,lineCap:.round)).rotationEffect(.degrees(-90)) }.frame(width:size,height:size) }
}
struct TodayView: View {
    @EnvironmentObject var store: HabitStore
    @Binding var group: String
    @State private var date = Day.key(Date())
    @State private var catalog = false
    @State private var editing:Habit? = nil
    @State private var deleting:Habit? = nil
    @State private var showExcluded = false
    @State private var selected: Habit? = nil
    @AppStorage("repeat.weekMode") private var weekMode = "week"
    @AppStorage("repeat.showStreaks") private var showStreaks = true
    var scheduled:[Habit] { store.active.filter { (group.isEmpty || $0.group == group) && $0.scheduled(date) } }
    var habits:[Habit] { scheduled.filter{!store.isHidden($0,date) && !store.isSkipped($0,date)} }
    var excluded:[Habit] { scheduled.filter{store.isHidden($0,date) || store.isSkipped($0,date)} }
    var body: some View {
        NavigationStack {
            List {
                VStack(spacing:20) {
                    HStack {
                        Button { date = Day.shift(date,-7) } label: { Image(systemName:"chevron.left") }
                        Spacer()
                        Button { date = Day.key(Date()) } label: { Text(date == Day.key(Date()) ? "Hoy" : Day.date(date).formatted(.dateTime.day().month(.wide))).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button { date = min(Day.key(Date()),Day.shift(date,7)) } label: { Image(systemName:"chevron.right") }.disabled(Day.shift(Day.weekStart(date),7) > Day.key(Date()))
                    }.font(.caption).foregroundStyle(.secondary).padding(.horizontal,10)
                    HStack(spacing:0) {
                        ForEach(0..<7,id:\.self) { i in
                            let key = weekMode == "recent" ? Day.shift(date,i-6) : Day.shift(Day.weekStart(date),i)
                            Button { date = key } label: {
                                VStack(spacing:12) {
                                    Text(["Lun","Mar","Mié","Jue","Vie","Sáb","Dom"][(Calendar.current.component(.weekday,from:Day.date(key))+5)%7]).font(.caption2)
                                    ZStack { ProgressRing(ratio:store.percentage(key)); Text("\(Calendar.current.component(.day,from:Day.date(key)))").font(.system(size:14)) }
                                }.frame(maxWidth:.infinity).padding(.vertical,13).background { if key == date { Capsule().stroke(Color.repeatPink.opacity(0.13),lineWidth:1) } }
                            }.buttonStyle(.plain).foregroundStyle(key == date ? Color.primary : Color.secondary).disabled(key > Day.key(Date()))
                        }
                    }
                }.listRowInsets(EdgeInsets(top:23,leading:23,bottom:20,trailing:23)).listRowSeparator(.hidden).listRowBackground(Color.clear)
                    ForEach(habits) { h in
                        HabitSwipeRow(habit:h,date:date,open:{selected = h},complete:{store.complete(h,date); if h.memoAfter { selected = h }},edit:{editing = h},delete:{deleting = h})
                    }.listRowInsets(EdgeInsets(top:0,leading:23,bottom:18,trailing:23)).listRowSeparator(.hidden).listRowBackground(Color.clear)
                VStack(spacing:20) {
                    if !excluded.isEmpty { DisclosureGroup(isExpanded:$showExcluded) { ForEach(excluded) { h in HStack { Text(h.icon); Text(h.name); Spacer(); Text(store.isSkipped(h,date) ? "Saltado" : "Oculto").font(.caption).foregroundStyle(.secondary); Button("Mostrar") { store.hide(h,date,false); if store.isSkipped(h,date) { store.skip(h,date,false) } } }.font(.subheadline).padding(.vertical,8) } } label: { Text("Saltados y ocultos (\(excluded.count))").font(.caption).foregroundStyle(.secondary) } }
                    if habits.isEmpty {
                        VStack(spacing:18) {
                            Text("🌱").font(.system(size:68)).frame(width:155,height:155).background(Color.repeatPink.opacity(0.07),in:Circle())
                            Text(store.active.isEmpty ? "Un pequeño paso.\nCada día." : "Hoy, a tu ritmo.").font(.system(size:30,weight:.semibold)).multilineTextAlignment(.center)
                            Text(store.active.isEmpty ? "Crea todos los hábitos que quieras.\nEste espacio es solo para ti." : "No hay hábitos programados\npara este día y grupo.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button { catalog = true } label: { Label("Crear un hábito",systemImage:"plus").padding(.horizontal,20).padding(.vertical,11) }.buttonStyle(.borderedProminent).clipShape(Capsule())
                        }.frame(maxWidth:.infinity).padding(.top,35)
                    } else {
                        VStack(spacing:9) {
                            HStack { Text("\(habits.filter{$0.progress(date,store.entries).done}.count) de \(habits.count) metas completadas"); Spacer(); Text("\(Int(store.percentage(date,habits)*100))%") }.font(.caption2).foregroundStyle(.secondary)
                            SwiftUI.ProgressView(value:store.percentage(date,habits))
                        }.padding(.top,7)
                    }
                }.listRowInsets(EdgeInsets(top:0,leading:23,bottom:23,trailing:23)).listRowSeparator(.hidden).listRowBackground(Color.clear)
            }.listStyle(.plain).scrollContentBackground(.hidden).navigationTitle("Hoy").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarLeading) { Menu { Button("Todos") { group = "" }; ForEach(store.groups,id:\.self) { g in Button(g) { group = g } } } label: { HStack { Text(group.isEmpty ? "Todos" : group); Image(systemName:"chevron.down").font(.system(size:9)) }.font(.caption).foregroundStyle(.white).padding(.horizontal,12).padding(.vertical,5).background(Color.repeatPink,in:Capsule()) } }
                ToolbarItemGroup(placement:.topBarTrailing) { Button { catalog = true } label: { Image(systemName:"plus.circle.fill") } }
            }
            .sheet(isPresented:$catalog) { HabitCatalog() }
            .sheet(item:$editing) { HabitEditor(initial:$0) }
            .confirmationDialog("Eliminar este hábito y sus registros",isPresented:Binding(get:{deleting != nil},set:{if !$0 { deleting = nil }}),titleVisibility:.visible) { Button("Eliminar definitivamente",role:.destructive) { if let deleting { store.delete(deleting) }; deleting = nil }; Button("Cancelar",role:.cancel) { deleting = nil } } message: { Text("Esta acción no se puede deshacer. Puedes archivar el hábito para conservar su historial.") }
            .sheet(item:$selected) { HabitDetail(original:$0,date:date) }
            .task(id:date) { await store.refreshHealth(date:date) }
            .safeAreaInset(edge:.bottom) { if let f = store.focus { FocusBanner(focus:f) } }
        }
    }
    func newHabit() -> Habit { var h = Habit(); h.order = (store.state.snapshot.habits.map(\.order).max() ?? -1)+1; return h }
}
struct HabitCard: View {
    @EnvironmentObject var store: HabitStore
    @AppStorage("repeat.showStreaks") private var showStreaks = true
    var habit: Habit; var date: String; var open: () -> Void; var complete: () -> Void
    var body: some View {
        let p = habit.progress(date,store.entries)
        let streak = metrics(habit,store.entries)
        content(p,streak).padding(18)
            .foregroundStyle(Color.primary)
            .background { GeometryReader { geometry in
                ZStack(alignment:.leading) { Rectangle().fill(habit.tint.opacity(0.09)); Rectangle().fill(habit.tint.opacity(0.9)).frame(width:geometry.size.width * p.ratio) }
            } }
            .overlay { content(p,streak).padding(18).foregroundStyle(Color.black.opacity(0.8)).mask { GeometryReader { geometry in Rectangle().frame(width:geometry.size.width * p.ratio).frame(maxWidth:.infinity,alignment:.leading) } }.allowsHitTesting(false).accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius:16))
    }
    func content(_ p:Progress,_ streak:HabitMetrics) -> some View {
        HStack(spacing:12) {
            Button(action:open) {
                HStack(spacing:13) {
                    Text(habit.icon).font(.system(size:30))
                    VStack(alignment:.leading,spacing:3) { Text(habit.name).font(.system(size:17)); if !habit.description.isEmpty { Text(habit.description).font(.caption2).opacity(0.65) } }
                    Spacer(minLength:3)
                    VStack(alignment:.trailing,spacing:4) { if showStreaks && streak.current > 0 { Text("🔥 \(streak.current) \(streak.streakUnit)").font(.system(size:9)).opacity(0.7) }; Text(store.healthSource(habit.id)?.id == "weight" ? "\(number(p.value)) kg" : "\(number(p.value))/\(number(habit.goal))\(habit.unit)").font(.system(size:15)).lineLimit(1).minimumScaleFactor(0.7) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button(action:p.done || store.healthSource(habit.id) != nil ? open : complete) { Image(systemName:p.done ? "checkmark" : "plus").font(.system(size:12)).frame(width:27,height:27).background(.white.opacity(p.done ? 0.3 : 0.7),in:Circle()) }.buttonStyle(.plain).accessibilityLabel(p.done ? "Ver registro de \(habit.name)" : "Completar \(habit.name)")
        }
    }
}
struct HabitDetail: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) var dismiss
    var original: Habit; var date: String
    @State private var amount = "1"
    @State private var correcting = false
    @State private var editor = false
    @State private var memo = false
    @State private var stats = false
    @State private var countdown = true
    @State private var deleting = false
    @State private var correctionError:String? = nil
    var habit: Habit { store.state.snapshot.habits.first { $0.id == original.id } ?? original }
    var body: some View {
        let h = habit; let p = h.progress(date,store.entries)
        NavigationStack {
            ScrollView {
                VStack(spacing:23) {
                    HStack { Button { editor = true } label: { Label("Editar",systemImage:"pencil") }.disabled(store.focus?.habitId == h.id); Spacer(); Text(Day.date(date).formatted(.dateTime.day().month())).foregroundStyle(.secondary) }.font(.caption)
                    ZStack {
                        ProgressRing(ratio:p.ratio,color:h.tint,size:245)
                        VStack(spacing:17) { Text(h.icon).font(.system(size:43)); Text(number(p.value)).font(.system(size:43,weight:.semibold)); Text("/\(number(h.goal)) \(h.unit)").font(.subheadline).foregroundStyle(.secondary); if p.done { Label("Meta lograda",systemImage:"checkmark").font(.caption).foregroundStyle(h.tint) } }
                    }.padding(.vertical,30)
                    if h.isTimed && store.healthSource(h.id) == nil {
                        Picker("Temporizador",selection:$countdown) { Text("Cuenta atrás").tag(true); Text("Cronómetro").tag(false) }.pickerStyle(.segmented)
                        if let f = store.focus, f.habitId == h.id { FocusBanner(focus:f) }
                        else { Button { store.startFocus(h,date,countdown:countdown) } label: { Label(store.focus == nil ? "Iniciar enfoque" : "Otro temporizador activo",systemImage:"play.fill").frame(maxWidth:.infinity).padding(10) }.buttonStyle(.bordered).disabled(store.focus != nil || (countdown && p.done)) }
                    }
                    if store.healthSource(h.id) == nil { VStack(alignment:.leading,spacing:10) {
                        Text(correcting ? "Valor total del día" : "Añadir \(h.unit)").font(.caption).foregroundStyle(.secondary)
                        HStack { TextField("Cantidad",text:$amount).keyboardType(.decimalPad).padding(13).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:16)); Button(correcting ? "Guardar" : "Añadir") { log(h) }.buttonStyle(.borderedProminent).disabled(value == nil || value! < (correcting ? 0 : 0.000001)) }
                        Button(correcting ? "Volver a añadir" : "Corregir valor del día") { correcting.toggle(); amount = correcting ? String(store.entry(h,date)?.value ?? 0) : "1" }.font(.caption)
                    } } else { Label("Apple Health · Solo en este iPhone",systemImage:"heart.fill").font(.footnote).foregroundStyle(.secondary); Button("Actualizar Salud") { Task { do { if let source = store.healthSource(h.id) { try await store.health.request(source) }; await store.refreshHealth(date:date) } catch { store.error = error.localizedDescription } } }.disabled(store.readingHealth) }
                    if store.healthSource(h.id)?.id == "mindful" {
                        VStack(alignment:.leading,spacing:12) {
                            if correcting {
                                Text("Tiempo registrado del día (min)").font(.caption).foregroundStyle(.secondary)
                                HStack { TextField("Minutos",text:$amount).keyboardType(.decimalPad).padding(13).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:16)); Button("Guardar") { log(h) }.buttonStyle(.borderedProminent).disabled(value == nil || value! < 0) }
                            }
                            Button(correcting ? "Cancelar corrección" : "Corregir tiempo registrado") { correcting.toggle(); amount = String(store.entry(h,date)?.value ?? 0) }
                            if store.hasHealthCorrection(h,date) { Text("Tiempo corregido en Repeat").font(.caption).foregroundStyle(.secondary); Button("Usar tiempo de Apple Health") { if !store.correctHealth(h,date,value:nil) { correctionError = store.error; store.error = nil } } }
                        }.font(.subheadline)
                    }
                    Button { store.complete(h,date); if h.memoAfter { memo = true } } label: { Label(h.type == "quit" ? (p.done ? "Retirar confirmación" : "Confirmar dentro del límite") : p.done ? "Meta completada" : "Completar meta",systemImage:"checkmark").frame(maxWidth:.infinity).padding(11) }.buttonStyle(.borderedProminent).tint(h.tint).disabled(store.healthSource(h.id) != nil || (h.type == "build" ? p.done : !p.done && p.value > h.goal))
                    if let entry = store.entry(h,date),entry.value > 0 || entry.checked { Button("Restablecer progreso del día") { store.mutate(Operation(op:"entry",id:h.id,date:date,mode:"clear")) }.font(.caption2).foregroundStyle(.secondary).disabled(store.focus?.habitId == h.id || store.healthSource(h.id) != nil) }
                    if let e = store.entry(h,date),!e.note.isEmpty { Text(e.note).font(.subheadline).frame(maxWidth:.infinity,alignment:.leading).padding().background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18)) }
                    HStack { Button { memo = true } label: { Label("Nota",systemImage:"book.closed") }; Spacer(); Button { stats = true } label: { Label("Estadísticas",systemImage:"chart.bar") } }.font(.subheadline).padding(.top,15)
                }.padding(25)
            }.background(Color(.systemGroupedBackground)).navigationTitle("\(h.icon) \(h.name)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cerrar") { dismiss() } }; ToolbarItem(placement:.primaryAction) { Menu { Button("Editar",systemImage:"pencil") { editor = true }; Button("Eliminar hábito",systemImage:"trash",role:.destructive) { deleting = true } } label: { Image(systemName:"ellipsis") }.disabled(store.focus?.habitId == h.id) } }
            .confirmationDialog("Eliminar \(h.name)",isPresented:$deleting,titleVisibility:.visible) { Button("Eliminar hábito y sus registros",role:.destructive) { if store.delete(h) { dismiss() } }; Button("Cancelar",role:.cancel) {} } message: { Text("Esta acción no se puede deshacer.") }
            .alert("No se pudo guardar el tiempo",isPresented:Binding(get:{correctionError != nil},set:{if !$0 { correctionError = nil }})) { Button("Aceptar") {} } message: { Text(correctionError ?? "") }
            .sheet(isPresented:$editor) { HabitEditor(initial:h) }
            .sheet(isPresented:$memo) { MemoEditor(habit:h,date:date) }
            .sheet(isPresented:$stats) { OverviewView(habit:h) }
        }
    }
    var value: Double? { guard let v = Double(amount.replacingOccurrences(of:",",with:".")),v.isFinite,v <= 1e9 else { return nil }; return v }
    func log(_ h: Habit) { guard let value else { return }; if store.healthSource(h.id)?.id == "mindful" { if store.correctHealth(h,date,value:value) { correcting = false } else { correctionError = store.error; store.error = nil }; return }; if correcting { store.mutate(Operation(op:"entry",id:h.id,date:date,mode:"set",value:value)) } else { store.add(h,date,value) }; if h.memoAfter && h.progress(date,store.entries).done { memo = true } }
}
struct FocusBanner: View {
    @EnvironmentObject var store: HabitStore
    var focus: FocusSession
    private let tick = Timer.publish(every:1,on:.main,in:.common).autoconnect()
    @State private var now = Date()
    var body: some View {
        let elapsed = max(0,now.timeIntervalSince(focus.start)); let seconds = Int(focus.countdown ? max(0,focus.seconds-elapsed) : elapsed)
        HStack { Image(systemName:"timer"); Text(store.state.snapshot.habits.first{$0.id == focus.habitId}?.name ?? "Enfoque").lineLimit(1); Spacer(); Text(String(format:"%02d:%02d",seconds/60,seconds%60)).monospacedDigit(); Button { store.stopFocus() } label: { Image(systemName:"pause.fill") }.accessibilityLabel("Pausar y guardar tiempo") }.font(.subheadline).padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:20)).padding(.horizontal)
            .onReceive(tick) { date in now = date; if focus.countdown && date.timeIntervalSince(focus.start) >= focus.seconds { store.stopFocus() } }
    }
}
struct MemoEditor: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) var dismiss
    var habit: Habit; var date: String
    @State private var note = ""
    @State private var mood: Int? = nil
    var body: some View { NavigationStack { Form { Section(habit.name) { TextEditor(text:$note).frame(minHeight:180) } }.navigationTitle("Tu nota").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancelar") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("Guardar") { store.mutate(Operation(op:"entry",id:habit.id,date:date,mode:"note",note:limitedText(note,5000),mood:mood)); dismiss() } } }.onAppear { let e = store.entry(habit,date); note = e?.note ?? ""; mood = e?.mood } } }
}
