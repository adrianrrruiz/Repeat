import Foundation

struct HabitMetrics {
    var current = 0
    var best = 0
    var successes = 0
    var monthSuccesses = 0
    var streakUnit = "días"
}
func metrics(_ habit: Habit,_ entries: [Entry],today: String = Day.key(Date())) -> HabitMetrics {
    var result = HabitMetrics()
    let quota = habit.period == "day" && habit.frequency.hasSuffix("count")
    result.streakUnit = quota ? (habit.frequency == "week-count" ? "semanas" : habit.frequency == "month-count" ? "meses" : "ciclos") : habit.period == "day" ? "días" : habit.period == "week" ? "semanas" : habit.period == "month" ? "meses" : "periodos"
    guard habit.startDate <= today else { return result }
    var blocks: [String:(done:Bool,end:String)] = [:]
    var counts: [String:(days:Int,end:String)] = [:]
    var date = habit.startDate
    while date <= today {
        defer { date = Day.shift(date,1) }
        guard habit.scheduled(date),!entries.contains(where:{$0.habitId == habit.id && $0.date == date && $0.skipped == true}) else { continue }
        let p = habit.progress(date,entries)
        if p.done && habit.period == "day" { result.successes += 1; if date.hasPrefix(String(today.prefix(7))) { result.monthSuccesses += 1 } }
        if quota {
            var start: String; var end: String
            if habit.frequency == "week-count" { start = Day.weekStart(date); end = Day.shift(start,6) }
            else if habit.frequency == "month-count" { let interval = Calendar.current.dateInterval(of:.month,for:Day.date(date))!; start = Day.key(interval.start); end = Day.key(interval.end.addingTimeInterval(-1)) }
            else { start = Day.shift(habit.startDate,(Day.distance(habit.startDate,date)/max(1,habit.cycleDays))*max(1,habit.cycleDays)); end = Day.shift(start,max(1,habit.cycleDays)-1) }
            let old = counts[start] ?? (0,end); counts[start] = (old.days + (p.done ? 1 : 0),end)
        } else {
            let (start,end) = habit.bounds(date)
            if blocks[start] == nil { blocks[start] = (p.done,end); if p.done && habit.period != "day" { result.successes += 1; if date.hasPrefix(String(today.prefix(7))) { result.monthSuccesses += 1 } } }
        }
    }
    if quota { for (key,b) in counts { blocks[key] = (b.days >= habit.targetDays,b.end) } }
    var run = 0
    for key in blocks.keys.sorted() { let block = blocks[key]!; if block.done { run += 1; result.best = max(result.best,run) } else if block.end < today { run = 0 } }
    result.current = run
    return result
}
func rangeTotals(_ habits:[Habit],_ entries:[Entry],start:String,end:String) -> (Int,Int) {
    guard start <= end else { return (0,0) }; var total = 0,done = 0
    for h in habits {
        var slots: [String:Bool] = [:]; var quotas: [String:(Int,Int)] = [:]; var d = start
        while d <= end {
            if h.scheduled(d) && !entries.contains(where:{$0.habitId == h.id && $0.date == d && $0.skipped == true}) {
                if h.period == "day" && h.frequency.hasSuffix("count") {
                    let key = h.frequency == "week-count" ? Day.weekStart(d) : h.frequency == "month-count" ? String(d.prefix(7)) : String(Day.distance(h.startDate,d)/max(1,h.cycleDays))
                    let b = quotas[key] ?? (0,0); quotas[key] = (b.0+1,b.1+(h.progress(d,entries).done ? 1 : 0))
                } else { slots[h.bounds(d).0] = h.progress(d,entries).done }
            }; d = Day.shift(d,1)
        }
        total += slots.count; done += slots.values.filter{$0}.count
        for b in quotas.values { let target = min(b.0,h.targetDays); total += target; done += min(target,b.1) }
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
