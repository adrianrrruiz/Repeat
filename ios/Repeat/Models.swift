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
    var tint: Color { Color(hex: color) }
    var isTimed: Bool { ["sec","min","hr"].contains(unit) }
    var periodLabel: String { ["day":"día","week":"semana","month":"mes"][period] ?? "\(periodDays) días" }
    var goalLabel: String { "\(number(goal)) \(unit) / \(periodLabel)" }
    func scheduled(_ date: String) -> Bool {
        guard date >= startDate, endDate == nil || date <= endDate! else { return false }
        let d = Day.date(date)
        if frequency == "weekdays" { return days.contains((Calendar.current.component(.weekday, from: d) + 5) % 7 + 1) }
        if frequency == "monthdays" { return days.contains(Calendar.current.component(.day, from: d)) }
        if frequency == "cycle-days" { return days.contains(Day.distance(startDate,date) % max(1,cycleDays) + 1) }
        return true
    }
    func bounds(_ date: String) -> (String,String) {
        let d = Day.date(date)
        if period == "week" { let start = Day.weekStart(date); return (start,Day.shift(start,6)) }
        if period == "month", let interval = Calendar.current.dateInterval(of: .month, for: d) { return (Day.key(interval.start),Day.key(interval.end.addingTimeInterval(-1))) }
        if period == "custom" { let delta = Day.distance(startDate,date); let start = Day.shift(startDate,(delta / max(1,periodDays)) * max(1,periodDays)); return (start,Day.shift(start,max(1,periodDays)-1)) }
        return (date,date)
    }
    func progress(_ date: String, _ entries: [Entry]) -> Progress {
        let (start,end) = bounds(date)
        let rows = entries.filter { $0.habitId == id && $0.date >= start && $0.date <= end && $0.date >= startDate && (endDate == nil || $0.date <= endDate!) }
        let value = rows.reduce(0) { $0 + $1.value }
        let checked = rows.contains { $0.checked }
        let done = type == "quit" ? checked && value <= goal : value >= goal || checked
        return Progress(value: value,done: done,ratio: done ? 1 : type == "quit" ? 0 : min(1,value / max(0.001,goal)))
    }
}
struct Progress { var value: Double; var done: Bool; var ratio: Double }
struct Entry: Codable, Identifiable {
    var habitId: String; var date: String; var value: Double = 0; var checked = false; var note = ""; var mood: Int? = nil; var updatedAt = ISO8601DateFormatter().string(from: Date())
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
struct FocusSession: Codable { var habitId: String; var date: String; var start: Date; var seconds: Double; var countdown: Bool; var requestId = UUID().uuidString.lowercased() }

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
