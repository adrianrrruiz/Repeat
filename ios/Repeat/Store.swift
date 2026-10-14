import Foundation
import SwiftUI
import WebKit
import UserNotifications
import WidgetKit

@MainActor
final class HabitStore: ObservableObject {
    static let shared = HabitStore()
    @Published var state = SavedState()
    @Published var syncText = "En este iPhone"
    @Published var syncing = false
    @Published var connected = UserDefaults.standard.bool(forKey:"repeat.connected")
    @Published var error: String? = nil
    @Published var focus: FocusSession? = nil
    @Published var healthConfiguration = HealthConfiguration()
    @Published var readingHealth = false
    let health = HealthIntegration()
    private var schedulingReminders = false
    private var remindersNeedRefresh = false
    var entries:[Entry] { healthConfiguration.combinedEntries(manual:state.snapshot.entries) }
    static let origin = "https://repeat-habitos-personal.freevenus7.chatgpt.site"
    let site = URL(string:origin)!
    private let file: URL
    private var stopping = false
    private var loadFailure:String? = nil
    private let redirectGuard = NoRedirect()
    var active: [Habit] { state.snapshot.habits.filter { !$0.archived }.sorted { $0.order < $1.order } }
    var groups: [String] { Array(Set(active.map(\.group).filter { !$0.isEmpty })).sorted() }
    init() {
        file = URL.documentsDirectory.appending(path:"repeat-state-v2.json")
        if !FileManager.default.fileExists(atPath:file.path) {
            let candidates = [NativeStorage.stateURL,URL.documentsDirectory.appending(path:"repeat-state-v1.json")]
            for candidate in candidates where FileManager.default.fileExists(atPath:candidate.path) {
                do { let saved = try StateFile(url:candidate).read(); try StateFile(url:file).write(saved); loadFailure = nil; self.error = nil; break }
                catch { loadFailure = error.localizedDescription; self.error = "No se pudo recuperar el archivo anterior. Se conserva sin modificar: \(error.localizedDescription)" }
            }
        }
        if let bytes = try? Data(contentsOf:URL.documentsDirectory.appending(path:"repeat-health-local.json")),let config = try? JSONDecoder().decode(HealthConfiguration.self,from:bytes) { healthConfiguration = config }
        if FileManager.default.fileExists(atPath:file.path) { do { state = try StateFile(url:file).read() } catch { loadFailure = error.localizedDescription; self.error = "No se pudo leer el guardado. El archivo se conserva sin modificar." } }
        if let bytes = UserDefaults.standard.data(forKey:"repeat.focus"), let f = try? JSONDecoder().decode(FocusSession.self,from:bytes) { focus = f }
    }
    @discardableResult func save() -> Bool {
        guard loadFailure == nil else { error = "No se puede guardar hasta recuperar el archivo anterior. Se conserva sin modificar."; return false }; do { try StateFile(url:file).write(state); publishWidget(); return true }
        catch { self.error = (error as NSError).code == NSFileWriteOutOfSpaceError ? "No hay espacio en el iPhone para guardar. Tu personalización sigue en el formulario." : "No se pudo guardar en el iPhone. Tu personalización sigue en el formulario; vuelve a intentarlo."; return false }
    }
    func apply(_ m: Operation) {
        if m.op == "delete",let id = m.id { state.snapshot.habits.removeAll{$0.id == id}; state.snapshot.entries.removeAll{$0.habitId == id} }
        else if m.op == "habit", let h = m.habit { if let i = state.snapshot.habits.firstIndex(where:{$0.id == h.id}) { state.snapshot.habits[i] = h } else { state.snapshot.habits.append(h) } }
        else if m.op == "archive", let id = m.id, let i = state.snapshot.habits.firstIndex(where:{$0.id == id}) { state.snapshot.habits[i].archived = m.archived ?? true }
        else if m.op == "mood", let date = m.date, let mood = m.mood { state.snapshot.moods.removeAll { $0.date == date }; state.snapshot.moods.append(Mood(date:date,mood:mood,note:m.note ?? "")) }
        else if m.op == "entry", let id = m.id, let date = m.date {
            let i = state.snapshot.entries.firstIndex { $0.habitId == id && $0.date == date }
            var e = i.map { state.snapshot.entries[$0] } ?? Entry(habitId:id,date:date)
            switch m.mode {
            case "skip": e.skipped = m.checked ?? true
            case "increment": e.skipped = false; e.value = min(1e9,max(0,e.value + (m.value ?? 0))); e.checked = false
            case "set": e.skipped = false; e.value = max(0,m.value ?? 0); e.checked = false
            case "check": e.skipped = false; e.checked = m.checked ?? true
            case "clear": e.skipped = false; e.value = 0; e.checked = false
            case "note": e.note = m.note ?? ""; e.mood = m.mood
            default: break
            }
            e.updatedAt = ISO8601DateFormatter().string(from:Date())
            if let i { state.snapshot.entries[i] = e } else { state.snapshot.entries.append(e) }
        }
    }
    @discardableResult func mutate(_ m: Operation) -> Bool {
        let previous = state
        apply(m); state.queue.append(m)
        guard save() else { state = previous; return false }
        if ["habit","archive","entry","delete"].contains(m.op) { Task { await scheduleReminders() } }
        if connected { Task { await sync() } } else { syncText = "Guardado en el iPhone" }; return true
    }
    @discardableResult func storeHabit(_ h:Habit,effectiveDate:String = Day.key(Date())) -> Bool {
        let saved = state.snapshot.habits.first(where:{$0.id == h.id}).map{h.preservingMetrics(from:$0,effectiveDate:effectiveDate)} ?? h
        return mutate(Operation(op:"habit",habit:saved))
    }
    func entry(_ h: Habit,_ date: String) -> Entry? { entries.first { $0.habitId == h.id && $0.date == date } }
    @discardableResult func add(_ h:Habit,_ date:String,_ amount:Double) -> Bool { mutate(Operation(op:"entry",id:h.id,date:date,mode:"increment",value:amount)) }
    @discardableResult func complete(_ h:Habit,_ date:String) -> Bool {
        let p = h.progress(date,entries),effective = h.at(date)
        if effective.type == "quit" { return mutate(Operation(op:"entry",id:h.id,date:date,mode:"check",checked:!p.done)) }
        return add(h,date,max(0,effective.goal-p.value))
    }
    func isSkipped(_ h:Habit,_ date:String) -> Bool { state.snapshot.entries.contains{$0.habitId == h.id && $0.date == date && $0.skipped == true} }
    func skip(_ h:Habit,_ date:String,_ skipped:Bool = true) { mutate(Operation(op:"entry",id:h.id,date:date,mode:"skip",checked:skipped)) }
    func isHidden(_ h:Habit,_ date:String) -> Bool { (UserDefaults.standard.stringArray(forKey:"repeat.hidden."+date) ?? []).contains(h.id) }
    func hide(_ h:Habit,_ date:String,_ hidden:Bool = true) { var ids = UserDefaults.standard.stringArray(forKey:"repeat.hidden."+date) ?? []; ids.removeAll{$0 == h.id}; if hidden { ids.append(h.id) }; UserDefaults.standard.set(ids,forKey:"repeat.hidden."+date); objectWillChange.send() }
    func percentage(_ date: String,_ habits: [Habit]? = nil) -> Double { let hs = (habits ?? active).filter { $0.scheduled(date) && !isSkipped($0,date) }; return hs.isEmpty ? 0 : hs.reduce(0) { $0 + $1.progress(date,entries).ratio } / Double(hs.count) }
    func sync() async {
        guard !syncing else { return }
        syncing = true; defer { syncing = false }
        syncText = "Sincronizando…"
        do {
            let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
            let selected = cookies.filter { let domain = $0.domain.trimmingCharacters(in:CharacterSet(charactersIn:".")); return domain == site.host || site.host!.hasSuffix("." + domain) }
            guard !selected.isEmpty else { throw SyncError.signIn }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpShouldSetCookies = false
            let session = URLSession(configuration:configuration,delegate:redirectGuard,delegateQueue:nil)
            defer { session.invalidateAndCancel() }
            func request(_ op: Operation?) async throws -> Snapshot {
                var req = URLRequest(url:site.appending(path:"api/state")); req.timeoutInterval = 20
                for (k,v) in HTTPCookie.requestHeaderFields(with:selected) { req.setValue(v,forHTTPHeaderField:k) }
                if let op { req.httpMethod = "POST"; req.httpBody = try JSONEncoder().encode(op); req.setValue("application/json",forHTTPHeaderField:"Content-Type"); req.setValue(Self.origin,forHTTPHeaderField:"Origin") }
                let (data,response) = try await session.data(for:req)
                guard let http = response as? HTTPURLResponse else { throw SyncError.network }
                if [301,302,303,307,308,401,403].contains(http.statusCode) { throw SyncError.signIn }
                guard http.statusCode == 200 else { if let payload = try? JSONSerialization.jsonObject(with:data) as? [String:String],let message = payload["error"] { throw BackupError.invalid(message) }; throw SyncError.network }
                return try JSONDecoder().decode(Snapshot.self,from:data)
            }
            // Local records created offline keep their stable UUIDs and are sent before a remote snapshot replaces local state.
            while let op = state.queue.first {
                let remote = try await request(op)
                state.queue.removeFirst(); if state.queue.isEmpty { state.snapshot = remote }; save()
            }
            if state.queue.isEmpty { let remote = try await request(nil); state.snapshot = remote; for pending in state.queue { apply(pending) }; save() }
            connected = true; UserDefaults.standard.set(true,forKey:"repeat.connected"); syncText = "Todo sincronizado"; error = nil
        } catch SyncError.signIn { connected = false; UserDefaults.standard.set(false,forKey:"repeat.connected"); syncText = "Conecta tu cuenta para sincronizar" }
        catch let failure as BackupError { syncText = "Hay un cambio que requiere revisión"; self.error = failure.localizedDescription }
        catch { syncText = "Guardado local · sin conexión" }
    }
    func startFocus(_ h: Habit,_ date: String,countdown: Bool) {
        guard focus == nil else { return }; let effective = h.at(date),seconds = max(1,(effective.goal-h.progress(date,entries).value)*(effective.unit == "hr" ? 3600 : effective.unit == "min" ? 60 : 1))
        focus = FocusSession(habitId:h.id,date:date,start:Date(),seconds:seconds,countdown:countdown,unit:effective.unit)
        UserDefaults.standard.set(try? JSONEncoder().encode(focus),forKey:"repeat.focus")
        if let focus { FocusActivityController.start(focus,habit:h) }
        FocusSounds.shared.start(habitID:h.id)
        if countdown { Task { let center = UNUserNotificationCenter.current(); let settings = await center.notificationSettings(); if settings.authorizationStatus == .notDetermined { _ = try? await center.requestAuthorization(options:[.alert,.sound,.badge]) }; guard let current = focus,current.habitId == h.id else { return }; let remaining = current.start.addingTimeInterval(current.seconds).timeIntervalSinceNow; guard remaining > 0 else { return }; let content = UNMutableNotificationContent(); content.title = "Temporizador terminado"; content.body = "\(h.icon) \(h.name)"; content.sound = .default; try? await center.add(UNNotificationRequest(identifier:"repeat-focus",content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:max(1,remaining),repeats:false))) } }
    }
    func stopFocus() {
        guard !stopping, let f = focus, let h = state.snapshot.habits.first(where:{$0.id == f.habitId}) else { return }
        stopping = true
        let elapsed = min(max(0,Date().timeIntervalSince(f.start)),f.countdown ? f.seconds : 86400)
        let unit = f.unit ?? h.at(f.date).unit
        var op = Operation(op:"entry",id:h.id,date:f.date,mode:"increment",value:elapsed/(unit == "hr" ? 3600 : unit == "min" ? 60 : 1)); op.requestId = f.requestId
        // Persist progress and clear the timer before starting an asynchronous network request.
        if !state.queue.contains(where:{$0.requestId == f.requestId}),!mutate(op) { stopping = false; return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["repeat-focus"]); focus = nil; UserDefaults.standard.removeObject(forKey:"repeat.focus"); FocusActivityController.stop(); FocusSounds.shared.stop(); stopping = false
        if connected { Task { await sync() } }
    }
    func publishWidget() {
        let date = Day.key(Date())
        if UserDefaults.standard.bool(forKey:"repeat.lockEnabled") { if NativeStorage.writeWidget(WidgetSnapshot(date:date,habits:[],completion:0)) { WidgetCenter.shared.reloadAllTimelines() }; return }
        let eligible = active.filter { healthConfiguration.showOnWidgets || healthConfiguration.sources[$0.id] == nil }
        let automatic = eligible.filter{healthConfiguration.sources[$0.id] != nil}.map(\.id)
        let records = entries.filter{ e in eligible.contains{$0.id == e.habitId} }.map { WidgetRecord(habitId:$0.habitId,date:$0.date,value:$0.value,checked:$0.checked,skipped:$0.skipped) }
        var payload = WidgetSnapshot(date:date,habits:[],completion:0,schedules:eligible,records:records,automaticIDs:automatic)
        let current = payload.forDay(date); payload.habits = current.habits; payload.completion = current.completion
        if NativeStorage.writeWidget(payload) { WidgetCenter.shared.reloadAllTimelines() }
    }
    @discardableResult func saveHealth() -> Bool {
        do { try JSONEncoder().encode(healthConfiguration).write(to:URL.documentsDirectory.appending(path:"repeat-health-local.json"),options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]); publishWidget(); return true }
        catch { self.error = "No se pudo guardar la configuración de Salud."; return false }
    }
    func hasHealthCorrection(_ habit:Habit,_ date:String) -> Bool { healthConfiguration.corrections?[habit.id+":"+date] != nil }
    @discardableResult func correctHealth(_ habit:Habit,_ date:String,value:Double?) -> Bool {
        guard healthSource(habit.id)?.id == "mindful",value == nil || (value!.isFinite && value! >= 0 && value! <= 1e9) else { return false }
        let previous = healthConfiguration
        var corrections = healthConfiguration.corrections ?? [:]; corrections[habit.id+":"+date] = value; healthConfiguration.corrections = corrections
        guard saveHealth() else { healthConfiguration = previous; return false }; return true
    }
    func healthSource(_ id:String) -> HealthSource? { HealthSource.all.first { $0.id == healthConfiguration.sources[id] } }
    func configureHealth(_ habit:Habit,source:String?) {
        healthConfiguration.sources[habit.id] = source
        if source == nil { healthConfiguration.entries.removeAll{$0.habitId == habit.id}; healthConfiguration.corrections = healthConfiguration.corrections?.filter{!$0.key.hasPrefix(habit.id+":")} }
        saveHealth()
        if source != nil { Task { await refreshHealth() } }
    }
    func refreshHealth(date:String? = nil) async {
        guard !readingHealth,!healthConfiguration.sources.isEmpty else { return }; readingHealth = true; defer { readingHealth = false }
        let today = Day.key(Date())
        for habit in active {
            guard let source = healthSource(habit.id) else { continue }
            let start = date ?? max(habit.startDate,Day.shift(today,-30)),end = date ?? today
            guard start <= end else { continue }; var key = start
            while key <= end {
                let day = key; key = Day.shift(key,1)
                do {
                    let value = try await health.value(source,date:day)
                    healthConfiguration.entries.removeAll{$0.habitId == habit.id && $0.date == day}
                    if let value { healthConfiguration.entries.append(Entry(habitId:habit.id,date:day,value:max(0,value))) }
                } catch { /* HealthKit hides denied read permissions; never infer authorization from absence of samples. */ }
            }
        }
        saveHealth()
    }
    func reorder(_ ids:[String]) { for (index,id) in ids.enumerated() { if var h = state.snapshot.habits.first(where:{$0.id == id}),h.order != index { h.order = index; mutate(Operation(op:"habit",habit:h)) } } }
    func renameGroup(_ old:String,to name:String) { for var h in state.snapshot.habits.filter({$0.group == old}) { h.group = limitedText(name.trimmingCharacters(in:.whitespacesAndNewlines),60); mutate(Operation(op:"habit",habit:h)) } }
    @discardableResult func delete(_ habit:Habit) -> Bool { guard focus?.habitId != habit.id else { return false }; guard mutate(Operation(op:"delete",id:habit.id)) else { return false }; healthConfiguration.sources.removeValue(forKey:habit.id); healthConfiguration.entries.removeAll{$0.habitId == habit.id}; saveHealth(); return true }
    func duplicate(_ habit:Habit) { var h = habit; h.id = UUID().uuidString.lowercased(); h.name = limitedText(h.name+" (copia)",100); h.order = (state.snapshot.habits.map(\.order).max() ?? 0)+1; h.archived = false; storeHabit(h) }
    func restore(_ backup:Snapshot) {
        for h in backup.habits { apply(Operation(op:"habit",habit:h)); state.queue.append(Operation(op:"habit",habit:h)) }
        for e in backup.entries {
            let operations = [Operation(op:"entry",id:e.habitId,date:e.date,mode:"set",value:e.value),Operation(op:"entry",id:e.habitId,date:e.date,mode:"check",checked:e.checked),Operation(op:"entry",id:e.habitId,date:e.date,mode:"note",note:e.note,mood:e.mood),Operation(op:"entry",id:e.habitId,date:e.date,mode:"skip",checked:e.skipped ?? false)]
            for op in operations { apply(op); state.queue.append(op) }
        }
        for mood in backup.moods { let op = Operation(op:"mood",date:mood.date,note:mood.note,mood:mood.mood); apply(op); state.queue.append(op) }
        save(); Task { await scheduleReminders(); if connected { await sync() } }
    }
    func reconcileFocus() { if let f = focus,f.countdown,Date().timeIntervalSince(f.start) >= f.seconds { stopFocus() } }
    func scheduleReminders() async {
        if schedulingReminders { remindersNeedRefresh = true; return }; schedulingReminders = true
        defer { schedulingReminders = false; if remindersNeedRefresh { remindersNeedRefresh = false; Task { await scheduleReminders() } } }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers:(await center.pendingNotificationRequests()).filter { $0.identifier.hasPrefix("repeat:") }.map(\.identifier))
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        var candidates: [(Date,Habit,String)] = []
        let today = Day.key(Date())
        for offset in 0..<30 { let date = Day.shift(today,offset); for h in active where h.scheduled(date) && !isSkipped(h,date) && (date != today || !h.progress(date,entries).done) { for time in h.reminders { let pieces = time.split(separator:":").compactMap { Int($0) }; if pieces.count == 2 { var c = Calendar.current.dateComponents([.year,.month,.day],from:Day.date(date)); c.hour = pieces[0]; c.minute = pieces[1]; if let at = Calendar.current.date(from:c),at > Date() { candidates.append((at,h,time)); if UserDefaults.standard.bool(forKey:"repeat.superAlert."+h.id) { for delay in [5,10,15] { let repeatAt = at.addingTimeInterval(Double(delay)*60); if Day.key(repeatAt) == date { candidates.append((repeatAt,h,time+"-\(delay)")) } } } } } } } }
        for (at,h,time) in candidates.sorted(by:{$0.0 < $1.0}).prefix(60) {
            let content = UNMutableNotificationContent(); content.title = "\(h.icon) \(h.name)"; content.body = "Un pequeño paso para tu rutina. \(h.at(Day.key(at)).goalLabel)"; content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching:Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:at),repeats:false)
            try? await center.add(UNNotificationRequest(identifier:"repeat:\(h.id):\(Day.key(at)):\(time)",content:content,trigger:trigger))
        }
    }
}
enum SyncError: Error { case signIn, network }
final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession,task: URLSessionTask,willPerformHTTPRedirection response: HTTPURLResponse,newRequest request: URLRequest,completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
