import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var store: HabitStore
    var habit: Habit? = nil
    @State private var month = Date()
    @State private var filter = ""
    @State private var selected: Habit? = nil
    @State private var history:HistorySelection? = nil
    var habits: [Habit] { if let habit { return [habit] }; return filter.isEmpty ? store.active : store.active.filter{$0.id == filter} }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:20) {
                    if habit == nil { ScrollView(.horizontal,showsIndicators:false) { HStack { Button("Todos") { filter = "" }; ForEach(store.active) { h in Button { filter = h.id } label: { Text(h.icon).font(.title2).padding(7).background(filter == h.id ? Color.repeatPink.opacity(0.1) : .clear,in:RoundedRectangle(cornerRadius:12)) } } } } }
                    calendar
                    let stats = rangeTotals(habits,store.entries,start:Day.key(Calendar.current.dateInterval(of:.month,for:month)!.start),end:min(Day.key(Date()),Day.key(Calendar.current.dateInterval(of:.month,for:month)!.end.addingTimeInterval(-1))))
                    VStack(spacing:15) { ZStack { ProgressRing(ratio:stats.0 > 0 ? Double(stats.1)/Double(stats.0) : 0,color:habit?.tint ?? .repeatPink,size:170); VStack { Text("\(stats.0 > 0 ? Int(Double(stats.1)/Double(stats.0)*100) : 0)%").font(.system(size:35,weight:.semibold)); Text("Cumplimiento del mes").font(.caption2).foregroundStyle(.secondary) } }; Text("\(stats.1) de \(stats.0) metas").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).padding(27).background(.background,in:RoundedRectangle(cornerRadius:25))
                    let values = habits.map { metrics($0,store.entries) }
                    LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:15) { metric("Metas del mes",stats.1,"calendar.badge.checkmark",.cyan); metric("Metas completadas",values.reduce(0){$0+$1.successes},"checkmark.circle",.mint); metric("Racha actual",values.map(\.current).max() ?? 0,"flame",.purple); metric("Mejor racha",values.map(\.best).max() ?? 0,"medal",.orange) }
                    yearGrid
                }.padding(22)
            }.background(Color(.systemGroupedBackground)).navigationTitle(habit?.name ?? "Progreso").navigationBarTitleDisplayMode(.inline)
            .sheet(item:$selected) { HabitDetail(original:$0,date:Day.key(month)) }
            .sheet(item:$history) { HistoryDayView(date:$0.date) }
        }
    }
    var calendar: some View {
        let first = Calendar.current.dateInterval(of:.month,for:month)!.start
        let firstKey = Day.key(first); let start = Day.weekStart(firstKey)
        return VStack(spacing:17) {
            HStack { Button { month = Calendar.current.date(byAdding:.month,value:-1,to:first)! } label: { Image(systemName:"chevron.left") }; Spacer(); Text(month.formatted(.dateTime.month(.wide).year())).font(.subheadline.weight(.semibold)); Spacer(); Button { month = Calendar.current.date(byAdding:.month,value:1,to:first)! } label: { Image(systemName:"chevron.right") } }.foregroundStyle(.secondary)
            LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:7),spacing:13) {
                ForEach(Array(["L","M","X","J","V","S","D"].enumerated()),id:\.offset) { _,s in Text(s).font(.caption2) }
                ForEach(0..<42,id:\.self) { n in let d = Day.shift(start,n); let p = store.percentage(d,habits); Button { if let habit { month = Day.date(d); selected = habit } else { history = HistorySelection(date:d) } } label: { ZStack { ProgressRing(ratio:p,color:habit?.tint ?? .repeatPink,size:33); Text("\(Calendar.current.component(.day,from:Day.date(d)))").font(.caption) }.opacity(d.hasPrefix(String(firstKey.prefix(7))) ? 1 : 0.25) }.buttonStyle(.plain).disabled(d > Day.key(Date())) }
            }
        }.padding(20).background(.background,in:RoundedRectangle(cornerRadius:25))
    }
    var yearGrid: some View {
        let year = Calendar.current.component(.year,from:month); let start = String(format:"%04d-01-01",year)
        return VStack(alignment:.leading,spacing:16) {
            Text("Tu año, día a día").font(.subheadline.weight(.semibold))
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:2),count:26),spacing:3) { ForEach(0..<Day.distance(start,String(format:"%04d-01-01",year+1)),id:\.self) { n in let d = Day.shift(start,n); let p = store.percentage(d,habits); RoundedRectangle(cornerRadius:1).fill(p > 0 ? (habit?.tint ?? .repeatPink).opacity(0.25+p*0.75) : Color(.systemGray6)).frame(height:8) } }
        }.padding(20).background(.background,in:RoundedRectangle(cornerRadius:25))
    }
    func metric(_ title:String,_ value:Int,_ symbol:String,_ color:Color) -> some View { VStack(alignment:.leading,spacing:16) { Image(systemName:symbol).foregroundStyle(color).font(.title2); Text("\(value)").font(.system(size:30,weight:.semibold)); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading).padding(20).background(.background,in:RoundedRectangle(cornerRadius:22)) }
}
struct GroupsView: View {
    @EnvironmentObject var store: HabitStore
    var choose: (String) -> Void
    var body: some View { NavigationStack { ScrollView { VStack(alignment:.leading,spacing:22) { Text("Todo en su lugar.").font(.title2.weight(.semibold)); Text("Organiza tus hábitos con grupos personales.").font(.subheadline).foregroundStyle(.secondary); ForEach(store.groups,id:\.self) { g in Button { choose(g) } label: { HStack { Text("🌿").font(.largeTitle); VStack(alignment:.leading) { Text(g).font(.headline); Text("\(store.active.filter{$0.group == g}.count) hábitos").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"chevron.right") }.padding(22).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:22)) }.buttonStyle(.plain) }; if store.groups.isEmpty { ContentUnavailableView("Tus rutinas, organizadas",systemImage:"folder",description:Text("Escribe un grupo al crear o editar un hábito.")) } }.padding(24) }.navigationTitle("Grupos").navigationBarTitleDisplayMode(.inline) } }
}
struct ReportsView: View {
    @EnvironmentObject var store: HabitStore
    @State private var period = "week"
    @State private var anchor = Date()
    @State private var shared:SharedFile? = nil
    var range: (String,String) { let interval = Calendar.current.dateInterval(of:period == "week" ? .weekOfYear : period == "month" ? .month : .year,for:anchor)!; if period == "week" { let start = Day.weekStart(Day.key(anchor)); return (start,Day.shift(start,6)) }; return (Day.key(interval.start),Day.key(interval.end.addingTimeInterval(-1))) }
    var body: some View {
        NavigationStack { ScrollView { VStack(spacing:25) {
            Picker("Informe",selection:$period) { Text("Semanal").tag("week"); Text("Mensual").tag("month"); Text("Anual").tag("year") }.pickerStyle(.segmented)
            HStack { Text("☀️").font(.largeTitle); Text("Un poquito mejor,\ncada día.").font(.title2.weight(.semibold)).foregroundStyle(Color.repeatPink); Spacer() }
            HStack { Button { shift(-1) } label: { Image(systemName:"chevron.left") }; Spacer(); Text(period == "week" ? "\(Day.date(range.0).formatted(.dateTime.day().month())) — \(Day.date(range.1).formatted(.dateTime.day().month()))" : anchor.formatted(period == "month" ? .dateTime.month(.wide).year() : .dateTime.year())).font(.subheadline); Spacer(); Button { shift(1) } label: { Image(systemName:"chevron.right") } }
            ForEach(store.active) { h in
                let stats = rangeTotals([h],store.entries,start:range.0,end:min(range.1,Day.key(Date())))
                VStack(alignment:.leading,spacing:14) {
                    HStack { Text(h.icon); Text(h.name); Spacer(); Text("\(stats.1)/\(stats.0)").font(.caption).foregroundStyle(.secondary) }
                    ScrollView(.horizontal,showsIndicators:false) {
                        HStack(spacing:4) { ForEach(0...Day.distance(range.0,range.1),id:\.self) { i in
                            let day = Day.shift(range.0,i)
                            let progress = h.progress(day,store.entries)
                            VStack(spacing:5) { RoundedRectangle(cornerRadius:4).fill(day <= Day.key(Date()) && h.scheduled(day) ? h.tint.opacity(progress.done ? 1 : 0.12+progress.ratio*0.5) : Color(.systemGray6)).frame(width:period == "week" ? 32 : 14,height:27); if period != "year" { Text("\(Calendar.current.component(.day,from:Day.date(day)))").font(.system(size:9)).foregroundStyle(.secondary) } }
                        } }
                    }
                    SwiftUI.ProgressView(value:stats.0 > 0 ? Double(stats.1)/Double(stats.0) : 0).tint(h.tint)
                }.padding(18).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18))
            }
            if store.active.isEmpty { ContentUnavailableView("Cada registro cuenta",systemImage:"list.bullet.clipboard",description:Text("Crea tu primer hábito para empezar tu informe.")) }
        }.padding(23) }.navigationTitle("Informes").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.primaryAction) { Button { shareReport() } label: { Image(systemName:"square.and.arrow.up") } } }.sheet(item:$shared) { ShareSheet(items:[$0.url]) } }
    }
    func shareReport() {
        var lines = ["Repeat · \(range.0) — \(range.1)", ""]
        for h in store.active { let stats = rangeTotals([h],store.entries,start:range.0,end:min(range.1,Day.key(Date()))); lines.append("\(h.icon) \(h.name): \(stats.1) de \(stats.0) metas") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Repeat-informe.txt")
        do { try lines.joined(separator:"\n").write(to:url,atomically:true,encoding:.utf8); shared = SharedFile(url:url) } catch { store.error = error.localizedDescription }
    }
    func shift(_ n:Int) { anchor = Calendar.current.date(byAdding:period == "week" ? .weekOfYear : period == "month" ? .month : .year,value:n,to:anchor)! }
}
struct SettingsView: View {
    @EnvironmentObject var store:HabitStore
    @State private var connection = false
    @State private var mood = false
    @AppStorage("repeat.lockEnabled") private var lockEnabled = false
    @AppStorage("repeat.personalQuote") private var quote = ""
    var body:some View {
        NavigationStack {
            Form {
                Section { HStack(spacing:16) { Text("🙂").font(.system(size:43)); VStack(alignment:.leading,spacing:5) { Text("Mi espacio").font(.title2.weight(.semibold)); Text("Hábitos sin límites").font(.caption).foregroundStyle(Color.repeatPink) } }.padding(.vertical,12) }
                Section("Cómo te has sentido") { moodWeek; Button("Registrar estado de ánimo") { mood = true } }
                Section("Frase diaria") { NavigationLink { DailyQuoteView() } label: { Text(quote.isEmpty ? DailyQuoteView.quotes[Calendar.current.ordinality(of:.day,in:.year,for:Date())! % DailyQuoteView.quotes.count] : quote).font(.headline).foregroundStyle(Color.repeatPink).padding(.vertical,20) } }
                Section("Tu rutina") { NavigationLink("Gestionar hábitos") { HabitManagerView() }; NavigationLink("Gestionar grupos") { GroupManagerView() }; NavigationLink("Apariencia") { AppearanceView() }; NavigationLink("Copia y exportación") { BackupView() }; NavigationLink("Apple Health") { HealthSettingsView() } }
                Section("Sincronización") { Button { connection = true } label: { Label(store.connected ? "Cuenta conectada" : "Conectar con el computador",systemImage:"icloud") }; HStack { Text(store.syncText).font(.caption).foregroundStyle(.secondary); Spacer(); if store.syncing { SwiftUI.ProgressView() } else if store.connected { Button { Task { await store.sync() } } label: { Image(systemName:"arrow.clockwise") } } }; if !store.state.queue.isEmpty { Text("\(store.state.queue.count) cambios pendientes de sincronizar").font(.caption).foregroundStyle(.secondary) } }
                Section { Toggle("Proteger con Face ID o código",isOn:$lockEnabled) } footer: { Text("Al activar el bloqueo, tus hábitos se ocultan en los widgets.") }
                Section("Widgets y temporizador") { Text("Añade el widget de Repeat desde la pantalla de inicio o bloqueo del iPhone. Los widgets muestran tus metas y permiten registrarlas. El temporizador aparece en la pantalla bloqueada y Dynamic Island cuando las Actividades en Vivo están permitidas.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Mi espacio").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$connection) { ConnectionView() }
            .sheet(isPresented:$mood) { MoodEditor(date:Day.key(Date())) }
        }
    }
    var moodWeek:some View {
        HStack { ForEach(0..<7,id:\.self) { i in let key = Day.shift(Day.weekStart(Day.key(Date())),i); let record = store.state.snapshot.moods.first{$0.date == key}; VStack(spacing:10) { Text(["L","M","X","J","V","S","D"][i]).font(.caption2); Text(record.map{["😭","🙁","😐","🙂","😄"][$0.mood-1]} ?? "\(Calendar.current.component(.day,from:Day.date(key)))").font(.callout).frame(maxWidth:.infinity).padding(.vertical,8).background(Color.repeatPink.opacity(0.06),in:Circle()) } } }
    }
}
struct HistorySelection:Identifiable { var date:String; var id:String { date } }
struct HistoryDayView: View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) var dismiss
    var date:String
    @State private var selected:Habit? = nil
    var body:some View { NavigationStack { ScrollView { VStack(spacing:15) { ForEach(store.active.filter{$0.scheduled(date)}) { h in HabitCard(habit:h,date:date,open:{selected = h},complete:{store.complete(h,date)}) } }.padding(22) }.navigationTitle(Day.date(date).formatted(.dateTime.day().month(.wide))).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cerrar") { dismiss() } } }.sheet(item:$selected) { HabitDetail(original:$0,date:date) } }
}

}
