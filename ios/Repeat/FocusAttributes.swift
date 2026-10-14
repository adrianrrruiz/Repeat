import ActivityKit
import Foundation

struct RepeatFocusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var start:Date; var end:Date; var countdown:Bool }
    var habitID:String
    var name:String
    var icon:String
    var color:String
}
