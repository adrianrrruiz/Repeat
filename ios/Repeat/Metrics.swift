import Foundation

struct HabitMetrics {
    var current = 0
    var best = 0
    var successes = 0
    var monthSuccesses = 0
    var streakUnit = "días"
}
func metrics(_ habit: Habit,_ entries: [Entry],today: String = Day.key(Date())) -> HabitMetrics {
    var result = HabitMetrics(); let current = habit.at(today)
    let quota = current.period == "day" && current.frequency.hasSuffix("count")
    result.streakUnit = quota ? (current.frequency == "week-count" ? "semanas" : current.frequency == "month-count" ? "meses" : "ciclos") : current.period == "day" ? "días" : current.period == "week" ? "semanas" : current.period == "month" ? "meses" : "periodos"
    guard habit.startDate <= today else { return result }
    var blocks: [String:(done:Bool,end:String)] = [:]
    var counts: [String:(days:Int,target:Int,end:String)] = [:]
    var date = habit.startDate
    while date <= today {
        defer { date = Day.shift(date,1) }
        guard habit.scheduled(date),!entries.contains(where:{$0.habitId == habit.id && $0.date == date && $0.skipped == true}) else { continue }
        let h = habit.at(date),p = habit.progress(date,entries)
        if p.done && h.period == "day" { result.successes += 1; if date.hasPrefix(String(today.prefix(7))) { result.monthSuccesses += 1 } }
        if h.period == "day" && h.frequency.hasSuffix("count") {
            let (start,end) = habit.quotaBounds(date),old = counts[start] ?? (0,h.targetDays,end)
            counts[start] = (old.days + (p.done ? 1 : 0),h.targetDays,end)
        } else {
            let (start,end) = habit.bounds(date)
            if blocks[start] == nil { blocks[start] = (p.done,end); if p.done && h.period != "day" { result.successes += 1; if date.hasPrefix(String(today.prefix(7))) { result.monthSuccesses += 1 } } }
        }
    }
    for (key,b) in counts { blocks[key] = (b.days >= b.target,b.end) }
    var run = 0
    for key in blocks.keys.sorted() { let block = blocks[key]!; if block.done { run += 1; result.best = max(result.best,run) } else if block.end < today { run = 0 } }
    result.current = run
    return result
}
func rangeTotals(_ habits:[Habit],_ entries:[Entry],start:String,end:String) -> (Int,Int) {
    guard start <= end else { return (0,0) }; var total = 0,done = 0
    for habit in habits {
        var slots: [String:Bool] = [:]; var quotas: [String:(days:Int,done:Int,target:Int)] = [:]; var d = start
        while d <= end {
            if habit.scheduled(d) && !entries.contains(where:{$0.habitId == habit.id && $0.date == d && $0.skipped == true}) {
                let h = habit.at(d)
                if h.period == "day" && h.frequency.hasSuffix("count") {
                    let key = habit.quotaBounds(d).0,b = quotas[key] ?? (0,0,h.targetDays)
                    quotas[key] = (b.days+1,b.done+(habit.progress(d,entries).done ? 1 : 0),h.targetDays)
                } else { slots[habit.bounds(d).0] = habit.progress(d,entries).done }
            }; d = Day.shift(d,1)
        }
        total += slots.count; done += slots.values.filter{$0}.count
        for b in quotas.values { let target = min(b.days,b.target); total += target; done += min(target,b.done) }
    }; return (total,done)
}
func limitedText(_ text:String,_ limit:Int) -> String {
    var result = "",count = 0
    for character in text { let size = String(character).utf16.count; if count + size > limit { break }; result.append(character); count += size }
    return result
}
struct BackupEnvelope: Decodable { var habits:[Habit]; var entries:[Entry]; var moods:[Mood] }
func readBackup(_ data:Data) throws -> Snapshot {
    guard data.count <= 10_000_000 else { throw BackupError.invalid("La copia supera 10 MB.") }
    let snapshot: Snapshot
    if let raw = try? JSONDecoder().decode(Snapshot.self,from:data) { snapshot = raw }
    else { let saved = try JSONDecoder().decode(SavedState.self,from:data); snapshot = saved.snapshot }
    guard snapshot.habits.count <= 10000,snapshot.entries.count <= 100000 else { throw BackupError.invalid("La copia es demasiado grande.") }
    let ids = Set(snapshot.habits.map(\.id))
    guard ids.count == snapshot.habits.count else { throw BackupError.invalid("Hay hábitos duplicados en la copia.") }
    for h in snapshot.habits {
        if let history = h.metricHistory {
            guard history.count <= 1000,Set(history.map(\.effectiveDate)).count == history.count,history.allSatisfy({validDay($0.effectiveDate)}) else { throw BackupError.invalid("El historial de metas no es válido.") }
            for revision in history {
                var old = h.at(revision.effectiveDate); old.metricHistory = nil
                _ = try readBackup(JSONEncoder().encode(Snapshot(habits:[old])))
            }
        }
        guard UUID(uuidString:h.id) != nil,!h.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,h.name.utf16.count <= 100,h.icon.utf16.count <= 24,h.description.utf16.count <= 300,h.group.utf16.count <= 60,h.unit.utf16.count <= 30,h.goal.isFinite,h.goal >= 0,h.goal <= 1e9,(h.type == "quit" || h.goal > 0),["build","quit"].contains(h.type),["day","week","month","custom"].contains(h.period),["daily","weekdays","week-count","monthdays","month-count","cycle-days","cycle-count"].contains(h.frequency),(1...365).contains(h.periodDays),(1...365).contains(h.cycleDays),validDay(h.startDate),h.endDate == nil || (validDay(h.endDate!) && h.endDate! >= h.startDate),h.order >= 0,h.order <= 1000000,["any","morning","afternoon","evening"].contains(h.timeOfDay),h.color.range(of:"^#[0-9A-Fa-f]{6}$",options:.regularExpression) != nil else { throw BackupError.invalid("Un hábito contiene datos inválidos.") }
        let maximum = h.frequency == "weekdays" ? 7 : h.frequency == "monthdays" ? 31 : h.cycleDays
        let targetMaximum = h.frequency == "week-count" ? 7 : h.frequency == "month-count" ? 31 : h.cycleDays
        guard h.days.allSatisfy({(1...365).contains($0)}),h.days.count <= 365,(1...365).contains(h.targetDays),!h.frequency.hasSuffix("count") || h.targetDays <= targetMaximum else { throw BackupError.invalid("La frecuencia de un hábito no es válida.") }
        if ["weekdays","monthdays","cycle-days"].contains(h.frequency) && (h.days.isEmpty || h.days.contains(where:{$0 > maximum})) { throw BackupError.invalid("Los días de un hábito no son válidos.") }
        guard h.reminders.count <= 10,h.reminders.allSatisfy({$0.range(of:"^([01][0-9]|2[0-3]):[0-5][0-9]$",options:.regularExpression) != nil}) else { throw BackupError.invalid("Un recordatorio no es válido.") }
    }
    for e in snapshot.entries { guard ids.contains(e.habitId),validDay(e.date),e.value.isFinite,e.value >= 0,e.value <= 1e9,e.note.utf16.count <= 5000,e.mood == nil || (1...5).contains(e.mood!) else { throw BackupError.invalid("Un registro contiene datos inválidos.") } }
    for m in snapshot.moods { guard validDay(m.date),(1...5).contains(m.mood),m.note.utf16.count <= 5000 else { throw BackupError.invalid("Un estado de ánimo contiene datos inválidos.") } }
    guard Set(snapshot.entries.map(\.id)).count == snapshot.entries.count,Set(snapshot.moods.map(\.date)).count == snapshot.moods.count else { throw BackupError.invalid("La copia contiene registros duplicados.") }
    return snapshot
}
func validDay(_ key:String) -> Bool { key.range(of:"^[0-9]{4}-[0-9]{2}-[0-9]{2}$",options:.regularExpression) != nil && Day.key(Day.date(key)) == key && key >= "1900-01-01" && key <= "2199-12-31" }
enum BackupError: LocalizedError { case invalid(String); var errorDescription:String? { switch self { case .invalid(let message):return message } } }
