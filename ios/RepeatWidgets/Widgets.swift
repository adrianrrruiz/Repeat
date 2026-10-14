import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

struct HabitTimelineEntry: TimelineEntry { var date:Date; var summary:WidgetSnapshot }
struct HabitTimelineProvider: TimelineProvider {
    func placeholder(in context:Context) -> HabitTimelineEntry { HabitTimelineEntry(date:Date(),summary:WidgetSnapshot(date:Day.key(Date()),habits:[],completion:0)) }
    func getSnapshot(in context:Context,completion:@escaping(HabitTimelineEntry)->Void) { completion(entry(Date())) }
    func getTimeline(in context:Context,completion:@escaping(Timeline<HabitTimelineEntry>)->Void) { let now = Date(); let midnight = Calendar.current.startOfDay(for:Calendar.current.date(byAdding:.day,value:1,to:now)!); completion(Timeline(entries:[entry(now),entry(midnight)],policy:.after(midnight.addingTimeInterval(60)))) }
    func entry(_ date:Date) -> HabitTimelineEntry { let summary = NativeStorage.readWidget()?.forDay(Day.key(date)) ?? WidgetSnapshot(date:Day.key(date),habits:[],completion:0); return HabitTimelineEntry(date:date,summary:summary) }
}
struct RepeatHabitsWidget: Widget {
    var body:some WidgetConfiguration { StaticConfiguration(kind:"RepeatHabits",provider:HabitTimelineProvider()) { entry in HabitWidgetView(entry:entry).containerBackground(.fill.tertiary,for:.widget) }.configurationDisplayName("Tus hábitos").description("Registra tu progreso desde la pantalla de inicio o bloqueo.").supportedFamilies([.systemSmall,.systemMedium,.systemLarge,.accessoryCircular,.accessoryRectangular,.accessoryInline]) }
}
struct WidgetRing: View { var ratio:Double; var body:some View { ZStack { Circle().stroke(Color.repeatPink.opacity(0.2),lineWidth:5); Circle().trim(from:0,to:max(0,min(1,ratio))).stroke(Color.repeatPink,style:StrokeStyle(lineWidth:5,lineCap:.round)).rotationEffect(.degrees(-90)) } } }
struct HabitWidgetView: View {
    var entry:HabitTimelineEntry
    @Environment(\.widgetFamily) private var family
    var summary:WidgetSnapshot { entry.summary }
    var body:some View {
        Group {
            if family == .accessoryInline { Text("Repeat · \(summary.habits.filter{$0.done}.count)/\(summary.habits.count) metas") }
            else if family == .accessoryCircular { ZStack { WidgetRing(ratio:summary.completion); Text("\(Int(summary.completion*100))%").font(.caption.weight(.semibold)) }.widgetURL(URL(string:"repeat://today")) }
            else if family == .accessoryRectangular { VStack(alignment:.leading) { Text("Repeat").font(.headline); Text("\(summary.habits.filter{$0.done}.count) de \(summary.habits.count) metas").font(.caption); ProgressView(value:summary.completion).tint(.repeatPink) }.widgetURL(URL(string:"repeat://today")) }
            else if summary.habits.isEmpty { VStack(spacing:10) { Text("🌱").font(.largeTitle); Text("Un pequeño paso. Cada día.").font(.headline).multilineTextAlignment(.center); Text("Abre Repeat").font(.caption).foregroundStyle(.secondary) }.widgetURL(URL(string:"repeat://today")) }
            else if family == .systemSmall { VStack(alignment:.leading,spacing:12) { Text("repeat.").font(.headline); ZStack { WidgetRing(ratio:summary.completion).frame(width:65,height:65); Text("\(summary.habits.filter{$0.done}.count)/\(summary.habits.count)").font(.headline) }.frame(maxWidth:.infinity); Text("Metas de hoy").font(.caption2).foregroundStyle(.secondary) }.widgetURL(URL(string:"repeat://today")) }
            else { VStack(alignment:.leading,spacing:family == .systemLarge ? 9 : 6) { HStack { Text("repeat.").font(.headline); Spacer(); Text("\(Int(summary.completion*100))%").font(.caption).foregroundStyle(Color.repeatPink) }; ForEach(Array(summary.habits.prefix(family == .systemLarge ? 8 : 3))) { h in HStack(spacing:7) { Link(destination:URL(string:"repeat://habit?id=\(h.id)")!) { HStack { Text(h.icon); Text(h.name).font(.caption).lineLimit(1); Spacer(); Text("\(number(h.value))/\(number(h.goal))").font(.caption2).foregroundStyle(.secondary) } }; if h.automatic != true { Button(intent:CompleteHabitIntent(id:h.id)) { Image(systemName:h.done ? "checkmark.circle.fill" : "circle").foregroundStyle(Color(hex:h.color)) }.buttonStyle(.plain).disabled(h.done) } else { Image(systemName:"heart.fill").font(.caption2).foregroundStyle(Color(hex:h.color)) } }.padding(.vertical,4) } } }
        }.privacySensitive()
    }
}
struct RepeatFocusWidget: Widget {
    var body:some WidgetConfiguration { ActivityConfiguration(for:RepeatFocusAttributes.self) { context in HStack { Text(context.attributes.icon).font(.title); VStack(alignment:.leading) { Text(context.attributes.name).font(.headline); activityTime(context) }; Spacer(); Button(intent:PauseFocusIntent()) { Image(systemName:"pause.fill") }.buttonStyle(.plain) }.padding().activityBackgroundTint(Color(hex:context.attributes.color).opacity(0.12)).activitySystemActionForegroundColor(.primary).privacySensitive() } dynamicIsland: { context in DynamicIsland { DynamicIslandExpandedRegion(.leading) { Text(context.attributes.icon).font(.title) }; DynamicIslandExpandedRegion(.trailing) { activityTime(context) }; DynamicIslandExpandedRegion(.bottom) { HStack { Text(context.attributes.name).font(.headline); Spacer(); Button(intent:PauseFocusIntent()) { Label("Pausar",systemImage:"pause.fill") } } } } compactLeading: { Text(context.attributes.icon) } compactTrailing: { activityTime(context).font(.caption2).frame(maxWidth:70) } minimal: { Text(context.attributes.icon) }.widgetURL(URL(string:"repeat://habit?id=\(context.attributes.habitID)")).keylineTint(Color(hex:context.attributes.color)) } }
    @ViewBuilder func activityTime(_ context:ActivityViewContext<RepeatFocusAttributes>) -> some View { if context.state.countdown { Text(timerInterval:context.state.start...max(context.state.start,context.state.end),countsDown:true).monospacedDigit() } else { Text(context.state.start,style:.timer).monospacedDigit() } }
}
@main struct RepeatWidgets: WidgetBundle { var body:some Widget { RepeatHabitsWidget(); RepeatFocusWidget() } }
