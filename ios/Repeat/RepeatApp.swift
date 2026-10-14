import SwiftUI
import UserNotifications

@main
struct RepeatApp: App {
    @StateObject private var store = HabitStore.shared
    @Environment(\.scenePhase) var phase
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).tint(.repeatPink).task { store.publishWidget(); if store.connected { await store.sync() } } }
        .onChange(of:phase) { _,value in if value == .active { Task { if store.connected { await store.sync() }; store.reconcileFocus(); await store.refreshHealth(); await store.scheduleReminders() } } }
    }
}
