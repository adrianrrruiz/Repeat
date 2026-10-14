import Foundation

func check(_ condition: @autoclosure () -> Bool,_ message:String) { if !condition() { fatalError(message) } }
var h = Habit(); h.name = "Prueba"; h.startDate = "2026-10-01"; h.goal = 30; h.unit = "min"
h.frequency = "weekdays"; h.days = [1,3,5]
check(h.scheduled("2026-10-12"),"Lunes programado")
check(!h.scheduled("2026-10-13"),"Martes fuera de frecuencia")
h.endDate = "2026-10-20"; check(!h.scheduled("2026-10-21"),"Respeta fecha final")
h.frequency = "daily"; h.endDate = nil; h.period = "week"; h.goal = 60
let entries = [Entry(habitId:h.id,date:"2026-10-12",value:20),Entry(habitId:h.id,date:"2026-10-13",value:40)]
check(h.progress("2026-10-13",entries).done,"Acumula meta semanal")
check(!h.progress("2026-10-19",entries).done,"Reinicia siguiente semana")
h.period = "day"; h.type = "quit"; h.goal = 0
check(!h.progress("2026-10-13",[]).done,"Evitar requiere confirmación")
check(h.progress("2026-10-13",[Entry(habitId:h.id,date:"2026-10-13",checked:true)]).done,"Confirma límite cero")
check(!h.progress("2026-10-13",[Entry(habitId:h.id,date:"2026-10-13",value:1,checked:true)]).done,"No cumple si excede límite")
h.frequency = "cycle-days"; h.cycleDays = 3; h.days = [1]
check(h.scheduled("2026-10-04"),"Ciclo desde inicio")
check(!h.scheduled("2026-10-05"),"Día fuera del ciclo")
check(Day.shift("2026-12-31",1) == "2027-01-01","Cambio de año")
let snapshot = Snapshot(habits:[h],entries:entries,moods:[Mood(date:"2026-10-13",mood:4,note:"Prueba")])
let bytes = try JSONEncoder().encode(snapshot)
let decoded = try JSONDecoder().decode(Snapshot.self,from:bytes)
check(decoded.habits[0].id == h.id && decoded.entries.count == 2 && decoded.moods[0].mood == 4,"Persistencia Codable")
print("12 comprobaciones nativas de fechas, metas y persistencia: correctas")
var daily = Habit(); daily.name = "Racha"; daily.startDate = "2026-10-10"
let completed = ["2026-10-10","2026-10-11","2026-10-12"].map { Entry(habitId:daily.id,date:$0,value:1) }
check(metrics(daily,completed,today:"2026-10-13").current == 3,"Hoy pendiente conserva racha")
check(metrics(daily,completed,today:"2026-10-14").current == 0,"Día pasado sin cumplir rompe racha")
check(metrics(daily,completed,today:"2026-10-14").best == 3,"Conserva mejor racha")
check(rangeTotals([daily],completed,start:"2026-10-10",end:"2026-10-13").0 == 4,"Cuatro metas diarias")
check(rangeTotals([daily],completed,start:"2026-10-10",end:"2026-10-13").1 == 3,"Tres metas completadas")
var quota = daily; quota.startDate = "2026-10-05"; quota.frequency = "week-count"; quota.targetDays = 2
let quotaEntries = ["2026-10-05","2026-10-07","2026-10-12","2026-10-13"].map { Entry(habitId:quota.id,date:$0,value:1) }
check(metrics(quota,quotaEntries,today:"2026-10-13").current == 2,"Racha de dos semanas con cuota")
check(metrics(quota,quotaEntries,today:"2026-10-13").streakUnit == "semanas","Unidad de racha semanal")
check(Day.distance("2024-01-01","2025-01-01") == 366,"Año bisiesto")
check(limitedText("🌟🌟a",4) == "🌟🌟","Límite UTF16 mantiene emojis enteros")
let valid = Snapshot(habits:[daily],entries:completed)
let restored = try readBackup(JSONEncoder().encode(valid))
check(restored.entries.count == 3,"Restaurar copia válida")
var invalid = valid; invalid.habits.append(daily)
do { _ = try readBackup(JSONEncoder().encode(invalid)); fatalError("Aceptó hábitos duplicados") } catch { }
invalid = valid; invalid.entries[0].date = "2026-02-30"
do { _ = try readBackup(JSONEncoder().encode(invalid)); fatalError("Aceptó fecha inexistente") } catch { }
print("12 comprobaciones adicionales de rachas, cuotas, copia y Unicode: correctas")
let repositoryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("repeat-persistence-"+UUID().uuidString)
defer { try? FileManager.default.removeItem(at:repositoryDirectory) }
let repository = StateFile(url:repositoryDirectory.appendingPathComponent("Documents/state.json"))
var customized = Habit(); customized.name = "Rutina personalizada"; customized.description = "Descripción larga con 🧘"; customized.group = "Bienestar"; customized.icon = "🧘"; customized.color = "#7895E0"; customized.goal = 2.5; customized.unit = "hr"; customized.frequency = "cycle-days"; customized.cycleDays = 5; customized.days = [1,3,5]; customized.period = "custom"; customized.periodDays = 10; customized.reminders = ["08:35","21:15"]; customized.memoAfter = true; customized.startDate = "2026-10-14"; customized.endDate = "2027-01-20"
let operation = Operation(op:"habit",habit:customized)
let customizedState = SavedState(snapshot:Snapshot(habits:[customized]),queue:[operation])
try repository.write(customizedState)
let disk = try repository.read()
check(disk.snapshot.habits.first == customized,"Guarda cada campo de un hábito personalizado")
check(disk.queue.first?.requestId == operation.requestId,"Guarda la cola con identificador estable")
let blockedPath = repositoryDirectory.appendingPathComponent("blocked")
try Data("archivo".utf8).write(to:blockedPath)
do { try StateFile(url:blockedPath.appendingPathComponent("state.json")).write(customizedState); fatalError("La escritura debería fallar") } catch { }
let afterFailure = try repository.read()
check(afterFailure.snapshot.habits.first == customized,"Un fallo no daña el último guardado")
let skipped = completed + [Entry(habitId:daily.id,date:"2026-10-13",skipped:true)]
check(metrics(daily,skipped,today:"2026-10-14").current == 3,"Saltar un día conserva la racha anterior")
check(rangeTotals([daily],skipped,start:"2026-10-10",end:"2026-10-13").0 == 3,"Un día saltado no cuenta como fallo")
print("5 comprobaciones de persistencia completa, fallo de disco y días saltados: correctas")
