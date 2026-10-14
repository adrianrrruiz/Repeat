import Foundation
import Darwin

/// Widget summaries never contain notes, authentication cookies, or the synchronization outbox.
struct WidgetHabit: Codable, Identifiable { var id:String; var name:String; var icon:String; var color:String; var value:Double; var goal:Double; var unit:String; var done:Bool; var automatic:Bool? = nil }
struct WidgetRecord: Codable { var habitId:String; var date:String; var value:Double; var checked:Bool }
struct WidgetSnapshot: Codable {
    var date:String; var habits:[WidgetHabit]; var completion:Double
    var schedules:[Habit]? = nil; var records:[WidgetRecord]? = nil; var automaticIDs:[String]? = nil
    func forDay(_ key:String) -> WidgetSnapshot {
        guard let schedules,let records else { return key == date ? self : WidgetSnapshot(date:key,habits:[],completion:0) }
        let entries = records.map { Entry(habitId:$0.habitId,date:$0.date,value:$0.value,checked:$0.checked) }
        let active = schedules.filter { !$0.archived && $0.scheduled(key) }
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
}
