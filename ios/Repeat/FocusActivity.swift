import ActivityKit
import Foundation

@MainActor
enum FocusActivityController {
    static func start(_ focus:FocusSession,habit:Habit) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for activity in Activity<RepeatFocusAttributes>.activities { Task { await activity.end(nil,dismissalPolicy:.immediate) } }
        let attributes = RepeatFocusAttributes(habitID:habit.id,name:habit.name,icon:habit.icon,color:habit.color)
        let state = RepeatFocusAttributes.ContentState(start:focus.start,end:focus.start.addingTimeInterval(focus.seconds),countdown:focus.countdown)
        _ = try? Activity.request(attributes:attributes,content:ActivityContent(state:state,staleDate:focus.countdown ? state.end : nil),pushType:nil)
    }
    static func stop() { for activity in Activity<RepeatFocusAttributes>.activities { Task { await activity.end(nil,dismissalPolicy:.immediate) } } }
}
