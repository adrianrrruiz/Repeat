import SwiftUI
import Charts

struct HabitDetail: View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) private var dismiss
    var original:Habit; var date:String
    @State private var editor = false
    @State private var memo = false
    @State private var stats = false
    @State private var keypad:MetricPadMode? = nil
    @State private var deleting = false
    @State private var resetting = false
    @State private var sleep:SleepSummary? = nil
    @State private var now = Date()
    @State private var style = 0
    @State private var countdown = true
    @State private var soundPicker = false
    private let tick = Timer.publish(every:1,on:.main,in:.common).autoconnect()
    var habit:Habit { store.state.snapshot.habits.first{$0.id == original.id} ?? original }
    var effective:Habit { habit.at(date) }
    var source:HealthSource? { store.healthSource(habit.id) }
    var timerHabit:Bool { effective.isTimed && source == nil }
    var session:FocusSession? { store.focus.flatMap{$0.habitId == habit.id && $0.date == date ? $0 : nil} }
    var body:some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    if source?.id == "sleep" { sleepBody }
                    else if source?.id == "weight" { weightBody }
                    else { standardBody(height:geometry.size.height) }
                }.scrollIndicators(.hidden)
            }
            .background(LinearGradient(colors:[habit.tint.opacity(0.21),habit.tint.opacity(0.04),Color(.systemBackground)],startPoint:.top,endPoint:.bottom).ignoresSafeArea())
            .navigationTitle("\(habit.icon) \(habit.name)\(source == nil ? "" : " ♥")").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button { dismiss() } label:{Image(systemName:"chevron.left")}.keyboardShortcut(.escape,modifiers:[]).accessibilityLabel("Volver") }
                ToolbarItem(placement:.primaryAction) { Menu {
                    Button("Editar",systemImage:"pencil") { editor = true }
                    Button("Corregir registro",systemImage:"slider.horizontal.3") { keypad = .set }.disabled(source != nil && source?.id != "mindful")
                    if source?.id == "mindful",store.hasHealthCorrection(habit,date) { Button("Usar tiempo de Apple Health",systemImage:"heart") { store.correctHealth(habit,date,value:nil) } }
                    Button(habit.archived ? "Recuperar" : "Archivar",systemImage:"archivebox") { if store.mutate(Operation(op:"archive",id:habit.id,archived:!habit.archived)) { dismiss() } }
                    Button("Eliminar hábito",systemImage:"trash",role:.destructive) { deleting = true }
                } label:{Image(systemName:"ellipsis")}.disabled(store.focus?.habitId == habit.id) }
            }
            .tint(habit.tint)
            .sheet(isPresented:$editor) { HabitEditor(initial:habit) }
            .sheet(isPresented:$memo) { MemoEditor(habit:habit,date:date) }
            .sheet(isPresented:$stats) { HabitStatsView(habit:habit) }
            .sheet(item:$keypad) { mode in MetricPad(habit:habit,date:date,mode:mode,onSaved:{ done in if done && habit.memoAfter { memo = true } }).presentationDetents([.height(470)]).presentationDragIndicator(.visible) }
            .sheet(isPresented:$soundPicker) { FocusSoundPicker(habitID:habit.id,color:habit.tint) }
            .confirmationDialog("Eliminar \(habit.name)",isPresented:$deleting,titleVisibility:.visible) { Button("Eliminar hábito y sus registros",role:.destructive) { if store.delete(habit) { dismiss() } }; Button("Cancelar",role:.cancel) {} } message:{Text("Esta acción no se puede deshacer.")}
            .confirmationDialog("Restablecer el registro de este día",isPresented:$resetting,titleVisibility:.visible) { Button("Restablecer",role:.destructive) { store.mutate(Operation(op:"entry",id:habit.id,date:date,mode:"clear")) }; Button("Cancelar",role:.cancel) {} }
            .onAppear { style = UserDefaults.standard.integer(forKey:"repeat.timerStyle."+habit.id); countdown = !UserDefaults.standard.bool(forKey:"repeat.stopwatch."+habit.id) }
            .onReceive(tick) { now = $0; store.reconcileFocus() }
            .task(id:date) { if source?.id == "sleep" { sleep = try? await store.health.sleepSummary(date:date) } }
        }
    }
    func standardBody(height:CGFloat) -> some View {
        let h = effective,p = habit.progress(date,store.entries),running = session != nil
        return VStack(spacing:0) {
            if date != Day.key(Date()) { Text(Day.date(date).formatted(.dateTime.day().month(.wide).year())).font(.caption).foregroundStyle(.secondary).padding(.top,12) }
            Spacer(minLength:30)
            if timerHabit {
                let factor = h.unit == "hr" ? 3600.0 : h.unit == "min" ? 60.0 : 1
                let elapsed = session.map{max(0,now.timeIntervalSince($0.start))} ?? 0
                let seconds = session.map{$0.countdown ? max(0,$0.seconds-elapsed) : p.value*factor+elapsed} ?? (countdown ? max(0,(h.goal-p.value)*factor) : p.value*factor)
                if style == 1 { FlipTime(seconds:seconds,color:habit.tint).padding(.horizontal,55) }
                else { ZStack {
                    DetailRing(ratio:countdown ? max(0,1-p.ratio-elapsed/max(1,h.goal*factor)) : min(1,p.ratio+elapsed/max(1,h.goal*factor)),color:habit.tint,size:260)
                    Text(clockTime(seconds)).font(.system(size:42,weight:.medium,design:.rounded)).monospacedDigit().minimumScaleFactor(0.6)
                }.accessibilityElement(children:.combine).accessibilityLabel("Tiempo \(clockTime(seconds))") }
                Text("\(number(p.value)) / \(number(h.goal)) \(h.unit)").font(.caption).foregroundStyle(.secondary).padding(.top,20)
            } else {
                ZStack {
                    DetailRing(ratio:p.ratio,color:habit.tint,size:250)
                    VStack(spacing:22) { Text(h.icon).font(.system(size:40)); HStack(spacing:22) {
                        if source == nil && p.value > 0 { Button { store.add(habit,date,-1) } label:{Image(systemName:"minus")}.accessibilityLabel("Restar uno").disabled(running) } else { Color.clear.frame(width:18,height:18) }
                        Button { if source == nil || source?.id == "mindful" { keypad = .set } } label:{Text(number(p.value)).font(.system(size:42,weight:.semibold)).foregroundStyle(Color.primary)}.buttonStyle(.plain).accessibilityLabel("\(number(p.value)) \(h.unit), corregir registro").disabled(source != nil && source?.id != "mindful")
                        if source == nil { Button { store.add(habit,date,1) } label:{Image(systemName:"plus")}.accessibilityLabel("Añadir uno").disabled(running) } else { Color.clear.frame(width:18,height:18) }
                    }; Text("/ \(number(h.goal)) \(h.unit)").font(.subheadline).foregroundStyle(.secondary) }
                }
                if source != nil { Label("Apple Health",systemImage:"heart.fill").font(.caption).foregroundStyle(.secondary).padding(.top,20) }
            }
            Spacer(minLength:35)
            HStack(spacing:0) {
                if source == nil { iconCircle("arrow.counterclockwise",label:"Restablecer progreso") { resetting = true }.disabled(running || p.value == 0 && !p.done) } else { Color.clear.frame(width:44,height:44) }
                Spacer()
                if timerHabit {
                    Button { if running { store.stopFocus() } else { store.startFocus(habit,date,countdown:countdown) } } label:{Image(systemName:running ? "pause.fill" : "play.fill").font(.title3).frame(width:108,height:41)}.buttonStyle(.borderedProminent).clipShape(Capsule()).accessibilityLabel(running ? "Pausar y guardar tiempo" : "Iniciar temporizador").disabled(store.focus != nil && !running || !running && countdown && p.done)
                } else if source == nil {
                    Button("Añadir") { keypad = .increment }.font(.subheadline).frame(width:104,height:41).background(habit.tint,in:Capsule()).foregroundStyle(.white)
                } else { Button("Actualizar Salud") { refreshHealth() }.font(.caption).frame(height:41).buttonStyle(.borderedProminent).clipShape(Capsule()).disabled(store.readingHealth) }
                Spacer()
                if timerHabit { iconCircle("plus",label:"Añadir tiempo") { keypad = .increment }.disabled(running) }
                else if source?.id == "mindful" { iconCircle("pencil",label:"Corregir tiempo registrado") { keypad = .set } }
                else if source == nil { iconCircle("checkmark",label:"Completar meta") { if store.complete(habit,date),habit.memoAfter { memo = true } }.disabled(h.type == "build" ? p.done : !p.done && p.value > h.goal) }
                else { Color.clear.frame(width:44,height:44) }
            }.padding(.horizontal,58).padding(.bottom,35)
            if store.hasHealthCorrection(habit,date) { Button("Usar tiempo de Apple Health") { store.correctHealth(habit,date,value:nil) }.font(.caption).padding(.bottom,18) }
            HStack {
                if timerHabit {
                    tool("Estilo","clock",.blue) { style = (style+1)%2; UserDefaults.standard.set(style,forKey:"repeat.timerStyle."+habit.id) }
                    tool("Sonido","music.note",.purple) { soundPicker = true }
                    tool(countdown ? "Cuenta atrás" : "Cronómetro",countdown ? "timer" : "stopwatch",.mint) { countdown.toggle(); UserDefaults.standard.set(!countdown,forKey:"repeat.stopwatch."+habit.id) }.disabled(running)
                }
                tool("Nota","book.closed.fill",.orange) { memo = true }
                tool("Estadísticas","chart.bar.fill",.cyan) { stats = true }
            }.padding(.horizontal,18).padding(.bottom,20)
            if let entry = store.entry(habit,date),!entry.note.isEmpty { Text(entry.note).font(.footnote).foregroundStyle(.secondary).padding(20) }
        }.frame(minHeight:max(570,height),alignment:.center)
    }
    var sleepBody:some View {
        let p = habit.progress(date,store.entries)
        return VStack(spacing:20) {
            ZStack { DetailRing(ratio:p.ratio,color:habit.tint,size:205); VStack(spacing:18) { Text(habit.icon).font(.system(size:32)); Text(durationText(p.value*3600)).font(.system(size:33,weight:.semibold)); Text("/ \(number(effective.goal)) \(effective.unit)").foregroundStyle(.secondary).font(.subheadline) } }.padding(.top,32)
            Text("Tu descanso").font(.title2.weight(.semibold))
            HStack { summaryCard("Duración",durationText(p.value*3600),"moon.fill"); summaryCard("Meta",durationText(effective.goal*3600),"target") }
            if let sleep,!sleep.segments.isEmpty {
                VStack(alignment:.leading,spacing:12) {
                    Text("Registro de sueño").font(.subheadline.weight(.semibold))
                    Chart(sleep.segments) { segment in RectangleMark(xStart:.value("Inicio",segment.start),xEnd:.value("Final",segment.end),yStart:.value("Fase",segment.level-0.35),yEnd:.value("Fase",segment.level+0.35)).foregroundStyle(segment.color) }.chartYAxis(.hidden).chartXAxis { AxisMarks(values:.stride(by:.hour,count:3)) { AxisValueLabel(format:.dateTime.hour().minute()) } }.frame(height:115)
                    HStack { Text(sleep.start.formatted(.dateTime.hour().minute())); Spacer(); Text(sleep.end.formatted(.dateTime.hour().minute())) }.font(.caption).foregroundStyle(.secondary)
                }.padding(18).background(.background,in:RoundedRectangle(cornerRadius:22))
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:14) { ForEach(SleepSegment.stages,id:\.self) { stage in summaryCard(SleepSegment.title(stage),sleep.duration(stage).map(durationText) ?? "—","circle.fill",color:SleepSegment.color(stage)) } }
                Text("Las fases que tu dispositivo no haya registrado aparecen sin datos.").font(.caption).foregroundStyle(.secondary)
            } else { ContentUnavailableView("Sin detalle de sueño",systemImage:"moon.zzz",description:Text("Aquí aparecerán las fases disponibles en Apple Health.")) }
            healthActions
            bottomTools
        }.padding(24)
    }
    var weightBody:some View {
        let records = store.entries.filter{$0.habitId == habit.id && $0.date <= date && $0.date >= Day.shift(date,-30) && $0.value > 0}.sorted{$0.date < $1.date}
        let latest = records.last,previous = records.dropLast().last
        return VStack(spacing:28) {
            HStack(alignment:.firstTextBaseline,spacing:6) { Text(latest.map{number($0.value)} ?? "—").font(.system(size:77,weight:.semibold)); Text("kg").font(.title3) }.padding(.top,48)
            if let latest { Text(Day.date(latest.date).formatted(.dateTime.day().month().year())).font(.caption).foregroundStyle(.secondary) }
            Button("Actualizar Salud") { refreshHealth() }.buttonStyle(.borderedProminent).clipShape(Capsule()).disabled(store.readingHealth)
            if !records.isEmpty { Chart(records) { e in AreaMark(x:.value("Fecha",Day.date(e.date)),yStart:.value("Base",max(0,(records.map(\.value).min() ?? 0)-2)),yEnd:.value("Peso",e.value)).foregroundStyle(LinearGradient(colors:[habit.tint.opacity(0.25),habit.tint.opacity(0.01)],startPoint:.top,endPoint:.bottom)); LineMark(x:.value("Fecha",Day.date(e.date)),y:.value("Peso",e.value)).foregroundStyle(habit.tint); PointMark(x:.value("Fecha",Day.date(e.date)),y:.value("Peso",e.value)).foregroundStyle(habit.tint) }.chartYScale(domain:max(0,(records.map(\.value).min() ?? 0)-2)...((records.map(\.value).max() ?? 0)+2)).frame(height:170) }
            HStack { summaryCard("Desde el anterior",latest.flatMap{last in previous.map{number(last.value-$0.value)+" kg"}} ?? "—","arrow.up.arrow.down"); summaryCard("Hasta la meta",latest.map{number(effective.goal-$0.value)+" kg"} ?? "—","target") }
            summaryCard("Promedio de 30 días",records.isEmpty ? "—" : number(records.reduce(0){$0+$1.value}/Double(records.count))+" kg","chart.line.uptrend.xyaxis")
            bottomTools
        }.padding(24)
    }
    var healthActions:some View { Button { refreshHealth() } label:{Label("Actualizar Salud",systemImage:"heart.fill")}.buttonStyle(.bordered).disabled(store.readingHealth) }
    var bottomTools:some View { HStack { tool("Nota","book.closed.fill",.orange){memo = true}; tool("Estadísticas","chart.bar.fill",.cyan){stats = true} }.padding(.vertical,10) }
    func refreshHealth() { Task { do { if let source { try await store.health.request(source) }; await store.refreshHealth(date:date); if source?.id == "sleep" { sleep = try await store.health.sleepSummary(date:date) } } catch { store.error = error.localizedDescription } } }
    func iconCircle(_ icon:String,label:String,action:@escaping()->Void) -> some View { Button(action:action) { Image(systemName:icon).font(.title3).frame(width:42,height:42).background(habit.tint.opacity(0.10),in:Circle()) }.accessibilityLabel(label) }
    func tool(_ title:String,_ icon:String,_ color:Color,action:@escaping()->Void) -> some View { Button(action:action) { VStack(spacing:8) { Image(systemName:icon).font(.system(size:17)).frame(width:34,height:34).background(color.opacity(0.1),in:Circle()).foregroundStyle(color); Text(title).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6) }.frame(maxWidth:.infinity) }.buttonStyle(.plain) }
    func summaryCard(_ title:String,_ value:String,_ icon:String,color:Color? = nil) -> some View { VStack(alignment:.leading,spacing:14) { Label(title,systemImage:icon).font(.caption).foregroundStyle(color ?? habit.tint); Text(value).font(.title2.weight(.semibold)).minimumScaleFactor(0.6).lineLimit(1) }.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(.background,in:RoundedRectangle(cornerRadius:22)) }
}

struct DetailRing:View {
    var ratio:Double; var color:Color; var size:CGFloat
    var body:some View { ZStack { Circle().stroke(Color(.systemBackground).opacity(0.85),lineWidth:16); Circle().trim(from:0,to:min(1,max(0,ratio))).stroke(color,style:StrokeStyle(lineWidth:16,lineCap:.round)).rotationEffect(.degrees(-90)) }.frame(width:size,height:size).animation(.easeOut(duration:0.3),value:ratio) }
}
func clockTime(_ seconds:Double) -> String { let value = Int(max(0,seconds)); return value >= 3600 ? String(format:"%d:%02d:%02d",value/3600,value/60%60,value%60) : String(format:"%02d:%02d",value/60,value%60) }
func durationText(_ seconds:Double) -> String { let minutes = Int(max(0,seconds)/60); return minutes >= 60 ? "\(minutes/60) h \(minutes%60) min" : "\(minutes) min" }
struct FlipTime:View {
    var seconds:Double; var color:Color
    var body:some View { let value = Int(max(0,seconds)); let groups = [String(format:"%02d",value/60),String(format:"%02d",value%60)]
        VStack(spacing:12) { ForEach(Array(groups.enumerated()),id:\.offset) { _,group in HStack(spacing:12) { ForEach(Array(group.enumerated()),id:\.offset) { _,digit in Text(String(digit)).font(.system(size:73,weight:.medium,design:.rounded)).foregroundStyle(color).frame(maxWidth:.infinity).frame(height:137).background(.background,in:RoundedRectangle(cornerRadius:25)).overlay { Rectangle().fill(color.opacity(0.12)).frame(height:2) } } } } }.accessibilityElement(children:.ignore).accessibilityLabel("Tiempo \(clockTime(seconds))")
    }
}
