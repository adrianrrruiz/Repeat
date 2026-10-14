import Foundation

struct StateFile {
    let url:URL
    func read() throws -> SavedState { try JSONDecoder().decode(SavedState.self,from:Data(contentsOf:url)) }
    func write(_ state:SavedState) throws {
        let data = try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
    }
}
struct EditorDraft:Codable,Equatable {
    var habit:Habit
    var goalText:String
    var reminderTimes:[Date]
    var healthEnabled:Bool
    var healthSourceID:String
    var superAlert:Bool
    static func url(isNew:Bool,id:String) -> URL { URL.documentsDirectory.appending(path:isNew ? "repeat-new-habit-draft-\(id).json" : "repeat-edit-draft-\(id).json") }
    static func read(isNew:Bool,id:String) -> EditorDraft? { guard let data = try? Data(contentsOf:url(isNew:isNew,id:id)) else { return nil }; return try? JSONDecoder().decode(Self.self,from:data) }
    func write(isNew:Bool,id:String) throws { try JSONEncoder().encode(self).write(to:Self.url(isNew:isNew,id:id),options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]) }
    static func newDrafts() -> [EditorDraft] {
        let files = (try? FileManager.default.contentsOfDirectory(at:URL.documentsDirectory,includingPropertiesForKeys:nil)) ?? []
        return files.filter{$0.lastPathComponent.hasPrefix("repeat-new-habit-draft-")}.compactMap { url in guard let data = try? Data(contentsOf:url) else { return nil }; return try? JSONDecoder().decode(Self.self,from:data) }
    }
    static func clear(isNew:Bool,id:String) { try? FileManager.default.removeItem(at:url(isNew:isNew,id:id)) }
}
