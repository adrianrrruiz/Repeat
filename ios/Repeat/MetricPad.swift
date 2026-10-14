import SwiftUI

enum MetricPadMode:String,Identifiable { case increment,set; var id:String { rawValue } }
struct MetricPad:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) private var dismiss
    var habit:Habit; var date:String; var mode:MetricPadMode
    var onSaved:((Bool)->Void)? = nil
    @State private var text = "0"
    @State private var unit = ""
    @State private var firstDigit = true
    @State private var failure:String? = nil
    @State private var note = false
    var effective:Habit { habit.at(date) }
    var automatic:Bool { store.healthSource(habit.id) != nil }
    var canEdit:Bool { !automatic || store.healthSource(habit.id)?.id == "mindful" }
    var value:Double? { guard let input = Double(text.replacingOccurrences(of:",",with:".")),input.isFinite else { return nil }; let result = input * secondsPerUnit(unit)/secondsPerUnit(effective.unit); return result.isFinite && result >= 0 && result <= 1e9 ? result : nil }
    var body:some View {
        VStack(spacing:14) {
            HStack { Button { dismiss() } label:{Image(systemName:"xmark")}.keyboardShortcut(.escape,modifiers:[]).accessibilityLabel("Cancelar registro"); Spacer(); Text(mode == .set ? Day.date(date).formatted(.dateTime.day().month().year()) : "Añadir \(effective.isTimed ? "tiempo" : "cantidad")").font(.subheadline.weight(.semibold)); Spacer(); Button { note = true } label:{Image(systemName:"book.closed")}.accessibilityLabel("Nota del día") }
            HStack(alignment:.firstTextBaseline,spacing:5) { Text(text).font(.system(size:34,weight:.semibold)).foregroundStyle(habit.tint).accessibilityLabel("Valor \(text)"); if mode == .set { Text("/ \(number(effective.goal*secondsPerUnit(effective.unit)/secondsPerUnit(unit)))").font(.title3).foregroundStyle(.secondary) }; Text(unit).foregroundStyle(.secondary) }.lineLimit(1).minimumScaleFactor(0.5)
            if effective.isTimed { HStack(spacing:16) { ForEach(["sec","min","hr"],id:\.self) { u in Button(u) { if let v = Double(text.replacingOccurrences(of:",",with:".")) { text = editableNumber(v*secondsPerUnit(unit)/secondsPerUnit(u)) }; unit = u }.font(.subheadline).frame(width:57,height:25).background(unit == u ? habit.tint : Color(.secondarySystemGroupedBackground),in:Capsule()).foregroundStyle(unit == u ? Color.white : Color.secondary) } } }
            if mode == .set { HStack {
                if !automatic { Button { if store.mutate(Operation(op:"entry",id:habit.id,date:date,mode:"skip",checked:!store.isSkipped(habit,date))) { dismiss() } } label:{Label(store.isSkipped(habit,date) ? "Reanudar" : "Saltar",systemImage:"forward.end.fill")}.tint(.purple)
                    Spacer(); Button { if store.complete(habit,date) { dismiss(); onSaved?(true) } } label:{Label("Completar",systemImage:"checkmark.circle.fill")}.tint(.green)
                } else { Label(store.healthSource(habit.id)?.id == "mindful" ? "Corrección en Repeat" : "Leído de Apple Health",systemImage:"heart.fill").foregroundStyle(.secondary) }
            }.font(.caption) }
            GeometryReader { geometry in
                let width = (geometry.size.width-24)/4
                HStack(alignment:.top,spacing:8) {
                    Grid(horizontalSpacing:8,verticalSpacing:9) {
                        GridRow { key("1"); key("2"); key("3") }
                        GridRow { key("4"); key("5"); key("6") }
                        GridRow { key("7"); key("8"); key("9") }
                        GridRow { Color.clear.frame(height:47); key("0"); key(",") }
                    }
                    VStack(spacing:9) { key("AC"); key("⌫"); confirm.frame(height:103) }.frame(width:width)
                }
            }.frame(height:215).disabled(!canEdit)
            if let failure { Text(failure).font(.caption).foregroundStyle(.red) }
            if !canEdit { Button("Actualizar Salud") { Task { await store.refreshHealth(date:date) } }.disabled(store.readingHealth) }
        }.padding(20).background(Color(.systemGroupedBackground)).tint(habit.tint)
        .onAppear { unit = effective.unit; text = mode == .set ? editableNumber(store.entry(habit,date)?.value ?? 0) : "0" }
        .sheet(isPresented:$note) { MemoEditor(habit:habit,date:date) }
    }
    var confirm:some View { Button { save() } label:{Image(systemName:"checkmark").font(.title2.weight(.medium)).frame(maxWidth:.infinity,maxHeight:.infinity).foregroundStyle(.green).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:17))}.buttonStyle(.plain).keyboardShortcut(.return,modifiers:[]).accessibilityLabel("Guardar registro").disabled(value == nil || mode == .increment && value == 0 || store.focus?.habitId == habit.id) }
    func key(_ title:String) -> some View { let shortcut:KeyEquivalent = title == "⌫" ? .delete : title == "AC" ? "a" : KeyEquivalent(title.first!); return Button { enter(title) } label:{Text(title).font(.title2.weight(.medium)).frame(maxWidth:.infinity,minHeight:47).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:17)).foregroundStyle(Color.primary)}.buttonStyle(.plain).keyboardShortcut(shortcut,modifiers:title == "AC" ? .command : []).accessibilityLabel(title == "AC" ? "Borrar cantidad" : title == "⌫" ? "Borrar último dígito" : title == "," ? "Separador decimal" : title) }
    func enter(_ key:String) {
        failure = nil
        if key == "AC" { text = "0"; firstDigit = true; return }
        if key == "⌫" { text = String(text.dropLast()); if text.isEmpty { text = "0" }; firstDigit = false; return }
        if firstDigit { text = "0"; firstDigit = false }
        if key == "," { if !text.contains(",") && !text.contains(".") { text += "," }; return }
        guard text.count < 15 else { return }; text = text == "0" ? key : text+key
    }
    func save() {
        guard canEdit,let value,mode == .set || value > 0,store.focus?.habitId != habit.id else { return }
        let wasDone = habit.progress(date,store.entries).done
        let saved = automatic ? store.correctHealth(habit,date,value:value) : store.mutate(Operation(op:"entry",id:habit.id,date:date,mode:mode.rawValue == "increment" ? "increment" : "set",value:value))
        guard saved else { failure = store.error ?? "No se pudo guardar el registro."; store.error = nil; return }
        let justDone = !wasDone && habit.progress(date,store.entries).done
        dismiss(); onSaved?(justDone)
    }
}
func secondsPerUnit(_ unit:String) -> Double { unit == "hr" ? 3600 : unit == "min" ? 60 : 1 }
struct HabitStatsView:View { var habit:Habit; var body:some View { OverviewView(habit:habit) } }

func editableNumber(_ value:Double) -> String { let text = String(value); return (text.hasSuffix(".0") ? String(text.dropLast(2)) : text).replacingOccurrences(of:".",with:",") }
