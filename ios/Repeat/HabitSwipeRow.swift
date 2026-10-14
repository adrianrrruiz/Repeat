import SwiftUI

struct HabitSwipeRow:View {
    @EnvironmentObject var store:HabitStore
    var habit:Habit
    var date:String
    var open:()->Void
    var complete:()->Void
    var edit:()->Void
    var delete:()->Void
    var body:some View {
        HabitCard(habit:habit,date:date,open:open,complete:complete)
            .swipeActions(edge:.leading,allowsFullSwipe:true) {
                Button(action:complete) { Label("Completar",systemImage:"checkmark") }.tint(.repeatPink).disabled(habit.progress(date,store.entries).done || store.healthSource(habit.id) != nil)
            }
            .swipeActions(edge:.trailing,allowsFullSwipe:false) {
                Button { store.hide(habit,date) } label: { Label("Ocultar",systemImage:"eye.slash") }.tint(.cyan)
                Button { store.skip(habit,date) } label: { Label("Saltar",systemImage:"forward.fill") }.tint(.orange).disabled(store.focus?.habitId == habit.id)
                Button(action:open) { Label("Añadir",systemImage:"plus") }.tint(.repeatPink)
            }
            .contextMenu { Button("Editar",systemImage:"pencil",action:edit).disabled(store.focus?.habitId == habit.id); Button("Eliminar",systemImage:"trash",role:.destructive,action:delete).disabled(store.focus?.habitId == habit.id) }
    }
}
