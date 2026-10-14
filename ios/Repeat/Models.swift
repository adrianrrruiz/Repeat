import Foundation
import SwiftUI

struct Habit: Codable, Identifiable, Hashable {
    var id = UUID().uuidString.lowercased()
    var name = ""
    var description = ""
    var icon = "⭐"
    var color = "#FF5B86"
    var group = ""
    var type = "build"
    var goal: Double = 1
    var unit = "veces"
    var period = "day"
    var periodDays = 7
    var frequency = "daily"
    var days = [1,2,3,4,5,6,7]
    var targetDays = 3
    var cycleDays = 7
    var timeOfDay = "any"
    var reminders: [String] = []
    var memoAfter = false
    var startDate = Day.key(Date())
    var endDate: String? = nil
    var archived = false
    var order = 0
    var metricHistory: [MetricRevision]? = nil
    var metric: HabitMetric { HabitMetric(type:type,goal:goal,unit:unit,period:period,periodDays:periodDays,frequency:frequency,days:days,targetDays:targetDays,cycleDays:cycleDays) }
    func at(_ date:String) -> Habit {
        guard let revision = metricHistory?.filter({$0.effectiveDate <= date}).max(by:{$0.effectiveDate < $1.effectiveDate}) else { return self }
        var result = self; let m = revision.metric
        result.type = m.type; result.goal = m.goal; result.unit = m.unit; result.period = m.period; result.periodDays = m.periodDays; result.frequency = m.frequency; result.days = m.days; result.targetDays = m.targetDays; result.cycleDays = m.cycleDays
        return result
    }
    func preservingMetrics(from original:Habit,effectiveDate:String) -> Habit {
        var result = self
        result.metricHistory = original.metricHistory
        guard metric != original.metric else { return result }
        var history = original.metricHistory ?? [MetricRevision(effectiveDate:original.startDate,metric:original.metric)]
        let effective = max(original.startDate,effectiveDate)
        history.removeAll{$0.effectiveDate == effective}; history.append(MetricRevision(effectiveDate:effective,metric:metric))
        result.metricHistory = history.sorted{$0.effectiveDate < $1.effectiveDate}
        return result
    }
    func revisionBounds(_ date:String) -> (String,String) {
        let revisions = (metricHistory ?? []).sorted{$0.effectiveDate < $1.effectiveDate}
        return (revisions.last(where:{$0.effectiveDate <= date})?.effectiveDate ?? startDate,revisions.first(where:{$0.effectiveDate > date}).map{Day.shift($0.effectiveDate,-1)} ?? endDate ?? "2199-12-31")
    }
    var tint: Color { Color(hex: color) }
    var isTimed: Bool { ["sec","min","hr"].contains(unit) }
    var periodLabel: String { ["day":"día","week":"semana","month":"mes"][period] ?? "\(periodDays) días" }
    var goalLabel: String { "\(number(goal)) \(unit) / \(periodLabel)" }
    func scheduled(_ date: String) -> Bool {
        guard date >= startDate, endDate == nil || date <= endDate! else { return false }
        let h = at(date)
        let d = Day.date(date)
        if h.frequency == "weekdays" { return h.days.contains((Calendar.current.component(.weekday, from: d) + 5) % 7 + 1) }
        if h.frequency == "monthdays" { return h.days.contains(Calendar.current.component(.day, from: d)) }
        if h.frequency == "cycle-days" { return h.days.contains(Day.distance(startDate,date) % max(1,h.cycleDays) + 1) }
        return true
    }
    func bounds(_ date: String) -> (String,String) {
        let h = at(date); var start = date,end = date
        let d = Day.date(date)
        if h.period == "week" { start = Day.weekStart(date); end = Day.shift(start,6) }
        if h.period == "month",let interval = Calendar.current.dateInterval(of:.month,for:d) { start = Day.key(interval.start); end = Day.key(interval.end.addingTimeInterval(-1)) }
        if h.period == "custom" { start = Day.shift(startDate,(Day.distance(startDate,date)/max(1,h.periodDays))*max(1,h.periodDays)); end = Day.shift(start,max(1,h.periodDays)-1) }
        let revision = revisionBounds(date)
        return (max(start,revision.0),min(end,revision.1))
    }
    func progress(_ date: String, _ entries: [Entry]) -> Progress {
        let h = at(date)
        let (start,end) = bounds(date)
        let rows = entries.filter { $0.habitId == id && $0.date >= start && $0.date <= end && $0.date >= startDate && (endDate == nil || $0.date <= endDate!) }
        let value = rows.reduce(0) { $0 + $1.value }
        let checked = rows.contains { $0.checked }
        let done = h.type == "quit" ? checked && value <= h.goal : value >= h.goal || checked
        return Progress(value:value,done:done,ratio:done ? 1 : h.type == "quit" ? 0 : min(1,value/max(0.001,h.goal)))
    }
    func quotaBounds(_ date:String) -> (String,String) {
        let h = at(date); var start:String,end:String
        if h.frequency == "week-count" { start = Day.weekStart(date); end = Day.shift(start,6) }
        else if h.frequency == "month-count" { let interval = Calendar.current.dateInterval(of:.month,for:Day.date(date))!; start = Day.key(interval.start); end = Day.key(interval.end.addingTimeInterval(-1)) }
        else { start = Day.shift(startDate,(Day.distance(startDate,date)/max(1,h.cycleDays))*max(1,h.cycleDays)); end = Day.shift(start,max(1,h.cycleDays)-1) }
        let revision = revisionBounds(date); return (max(start,revision.0),min(end,revision.1))
    }
}
struct HabitMetric: Codable,Hashable {
    var type:String; var goal:Double; var unit:String; var period:String; var periodDays:Int
    var frequency:String; var days:[Int]; var targetDays:Int; var cycleDays:Int
}
struct MetricRevision: Codable,Hashable { var effectiveDate:String; var metric:HabitMetric }
struct Progress { var value: Double; var done: Bool; var ratio: Double }
struct Entry: Codable, Identifiable {
    var habitId: String; var date: String; var value: Double = 0; var checked = false; var note = ""; var skipped:Bool? = nil; var mood: Int? = nil; var updatedAt = ISO8601DateFormatter().string(from: Date())
    var id: String { habitId + ":" + date }
}
struct Mood: Codable, Identifiable { var date: String; var mood: Int; var note: String; var id: String { date } }
struct Snapshot: Codable { var habits: [Habit] = []; var entries: [Entry] = []; var moods: [Mood] = [] }
struct Operation: Codable, Identifiable {
    var requestId = UUID().uuidString.lowercased()
    var op: String
    var habit: Habit? = nil
    var id: String? = nil
    var date: String? = nil
    var mode: String? = nil
    var value: Double? = nil
    var checked: Bool? = nil
    var note: String? = nil
    var mood: Int? = nil
    var archived: Bool? = nil
}
struct SavedState: Codable { var snapshot = Snapshot(); var queue: [Operation] = [] }
struct FocusSession: Codable { var habitId: String; var date: String; var start: Date; var seconds: Double; var countdown: Bool; var requestId = UUID().uuidString.lowercased(); var unit:String? = nil }

enum Day {
    static func key(_ date: Date) -> String { let c = Calendar.current.dateComponents([.year,.month,.day], from: date); return String(format:"%04d-%02d-%02d",c.year!,c.month!,c.day!) }
    static func date(_ key: String) -> Date { let p = key.split(separator:"-").compactMap { Int($0) }; guard p.count == 3 else { return Date() }; return Calendar.current.date(from: DateComponents(year:p[0],month:p[1],day:p[2],hour:12)) ?? Date() }
    static func shift(_ key: String, _ n: Int) -> String { self.key(Calendar.current.date(byAdding:.day,value:n,to:date(key))!) }
    static func distance(_ a: String,_ b: String) -> Int { Calendar.current.dateComponents([.day],from:Calendar.current.startOfDay(for:date(a)),to:Calendar.current.startOfDay(for:date(b))).day ?? 0 }
    static func weekStart(_ key: String) -> String { shift(key,-((Calendar.current.component(.weekday,from:date(key))+5)%7)) }
}
func number(_ value: Double) -> String { value.formatted(.number.locale(Locale(identifier:"es_CO")).precision(.fractionLength(0...2))) }
extension Color {
    init(hex: String) { let n = UInt32(hex.trimmingCharacters(in:CharacterSet(charactersIn:"#")),radix:16) ?? 0xFF5B86; self.init(red:Double((n>>16)&255)/255,green:Double((n>>8)&255)/255,blue:Double(n&255)/255) }
    static let repeatPink = Color(hex:"#FF5B86")
}
