import AppIntents
import WidgetKit

struct CompleteHabitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Completar hábito"
    static var description = IntentDescription("Registra la meta de hoy en Repeat.")
    @Parameter(title:"Identificador del hábito") var habitID:String
    init() {}
    init(id:String) { habitID = id }
    @MainActor func perform() async throws -> some IntentResult {
        #if !REPEAT_WIDGET
        let store = HabitStore.shared
        guard !UserDefaults.standard.bool(forKey:"repeat.lockEnabled"),let habit = store.active.first(where:{$0.id == habitID}),habit.scheduled(Day.key(Date())),store.healthSource(habitID) == nil else { return .result() }
        if !habit.progress(Day.key(Date()),store.entries).done { store.complete(habit,Day.key(Date())) }
        #endif
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
struct PauseFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pausar y guardar enfoque"
    @MainActor func perform() async throws -> some IntentResult {
        #if !REPEAT_WIDGET
        HabitStore.shared.stopFocus()
        #endif
        return .result()
    }
}
struct OpenRepeatIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir Repeat"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult { .result() }
}
struct RepeatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] { AppShortcut(intent:OpenRepeatIntent(),phrases:["Abrir mis hábitos en \(.applicationName)","Ver mi rutina en \(.applicationName)"],shortTitle:"Mi rutina",systemImageName:"checkmark.circle") }
}
