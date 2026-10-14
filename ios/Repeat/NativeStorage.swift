import Foundation
import Darwin

/// Widget summaries never contain notes, authentication cookies, or the synchronization outbox.
struct WidgetHabit: Codable, Identifiable { var id:String; var name:String; var icon:String; var color:String; var value:Double; var goal:Double; var unit:String; var done:Bool; var automatic:Bool? = nil }
struct WidgetRecord: Codable { var habitId:String; var date:String; var value:Double; var checked:Bool; var skipped:Bool? = nil }
struct WidgetSnapshot: Codable {
    var date:String; var habits:[WidgetHabit]; var completion:Double
    var schedules:[Habit]? = nil; var records:[WidgetRecord]? = nil; var automaticIDs:[String]? = nil
    func forDay(_ key:String) -> WidgetSnapshot {
        guard let schedules,let records else { return key == date ? self : WidgetSnapshot(date:key,habits:[],completion:0) }
        let entries = records.map { Entry(habitId:$0.habitId,date:$0.date,value:$0.value,checked:$0.checked,skipped:$0.skipped) }
        let active = schedules.filter { h in !h.archived && h.scheduled(key) && !records.contains(where:{$0.habitId == h.id && $0.date == key && $0.skipped == true}) }
        let summaries = active.map { h in let p = h.progress(key,entries); return WidgetHabit(id:h.id,name:h.name,icon:h.icon,color:h.color,value:p.value,goal:h.goal,unit:h.unit,done:p.done,automatic:automaticIDs?.contains(h.id) == true) }
        let ratio = active.isEmpty ? 0 : active.reduce(0) { $0 + $1.progress(key,entries).ratio } / Double(active.count)
        return WidgetSnapshot(date:key,habits:summaries,completion:ratio)
    }
}
enum NativeStorage {
    static let group = "group.com.adrianruiz.repeat"
    static var container: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:group) }
    static var stateURL: URL { (container ?? URL.documentsDirectory).appending(path:"repeat-state-v1.json") }
    static var widgetURL: URL? { container?.appending(path:"widget-summary.json") }
    static func writeWidget(_ summary:WidgetSnapshot) -> Bool {
        guard let url = widgetURL else { return false }; let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(summary) else { return false }
        if let previous = try? Data(contentsOf:url),previous == data { return false }
        do { try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]); return true } catch { return false }
    }
    static func readWidget() -> WidgetSnapshot? { guard let url = widgetURL,let data = try? Data(contentsOf:url) else { return nil }; return try? JSONDecoder().decode(WidgetSnapshot.self,from:data) }
}
struct HealthConfiguration: Codable {
    var sources: [String:String] = [:]
    var entries: [Entry] = []
    var showOnWidgets = false
    var corrections:[String:Double]? = nil
    func combinedEntries(manual:[Entry]) -> [Entry] {
        let automatic = entries.filter{sources[$0.habitId] != nil}
        var combined = manual.filter { e in sources[e.habitId] == nil || !automatic.contains(where:{$0.id == e.id}) }.map { e in var result = e; if sources[e.habitId] != nil { result.value = 0; result.checked = false }; return result }
        combined += automatic.map { e in var result = e; if let note = manual.first(where:{$0.id == e.id}) { result.note = note.note; result.mood = note.mood; result.skipped = note.skipped }; return result }
        for (key,value) in corrections ?? [:] {
            let parts = key.split(separator:":",maxSplits:1).map(String.init)
            guard parts.count == 2,sources[parts[0]] != nil else { continue }
            if let index = combined.firstIndex(where:{$0.id == key}) { combined[index].value = value; combined[index].checked = false }
            else { combined.append(Entry(habitId:parts[0],date:parts[1],value:value)) }
        }
        return combined
    }
}
