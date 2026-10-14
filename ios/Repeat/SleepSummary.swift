import SwiftUI

struct SleepSegment:Identifiable {
    var start:Date; var end:Date; var stage:String
    var id:String { "\(start.timeIntervalSince1970):\(end.timeIntervalSince1970):\(stage)" }
    static let stages = ["awake","rem","core","deep"]
    static func title(_ stage:String) -> String { ["awake":"Despierto","rem":"REM","core":"Ligero","deep":"Profundo","asleep":"Dormido"][stage] ?? stage }
    static func color(_ stage:String) -> Color { switch stage { case "awake":return .orange; case "rem":return .cyan; case "core":return .blue; case "deep":return .purple; default:return .mint } }
    var color:Color { Self.color(stage) }
    var level:Double { switch stage { case "awake":return 4; case "rem":return 3; case "core":return 2; case "deep":return 1; default:return 2 } }
}
struct SleepSummary {
    var segments:[SleepSegment]
    var start:Date { segments.map(\.start).min() ?? Date() }
    var end:Date { segments.map(\.end).max() ?? Date() }
    func duration(_ stage:String) -> Double? { let ranges = segments.filter{$0.stage == stage}.map{($0.start,$0.end)}; return ranges.isEmpty ? nil : mergedSeconds(ranges) }
}
