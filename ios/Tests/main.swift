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
var meditation = Habit(); meditation.name = "Meditación"; meditation.goal = 5; meditation.unit = "min"
let meditationDate = "2026-10-14"
let imported = Entry(habitId:meditation.id,date:meditationDate,value:2)
var healthConfig = HealthConfiguration(sources:[meditation.id:"mindful"],entries:[imported])
let note = Entry(habitId:meditation.id,date:meditationDate,note:"Nota preservada")
healthConfig.corrections = [imported.id:3.5]
let corrected = healthConfig.combinedEntries(manual:[note])
check(corrected.first?.value == 3.5,"Corrige minutos de atención plena en Repeat")
check(corrected.first?.note == note.note,"La corrección conserva la nota")
check(healthConfig.entries.first?.value == 2,"La lectura original de Salud permanece intacta")
check(meditation.progress(meditationDate,corrected).ratio == 0.7,"El progreso refleja el 70 por ciento")
healthConfig.entries[0].value = 5
check(healthConfig.combinedEntries(manual:[note]).first?.value == 3.5,"Actualizar Salud respeta la corrección")
healthConfig.corrections = nil
check(healthConfig.combinedEntries(manual:[note]).first?.value == 5,"Retirar corrección recupera el tiempo de Salud")
let oldHealth = try JSONDecoder().decode(HealthConfiguration.self,from:Data("{\"sources\":{},\"entries\":[],\"showOnWidgets\":false}".utf8))
check(oldHealth.corrections == nil,"Configuración anterior compatible")
print("7 comprobaciones de corrección de meditación y progreso parcial: correctas")
var reading = Habit(); reading.name = "Leer"; reading.startDate = "2026-10-01"; reading.goal = 20; reading.unit = "min"
let pastReading = Entry(habitId:reading.id,date:"2026-10-12",value:20,note:"Nota anterior")
var thirty = reading; thirty.goal = 30
thirty = thirty.preservingMetrics(from:reading,effectiveDate:"2026-10-14")
check(thirty.at("2026-10-12").goal == 20,"Conserva la meta antigua")
check(thirty.at("2026-10-14").goal == 30,"Aplica nueva meta desde su fecha")
check(thirty.progress("2026-10-12",[pastReading]).done,"Un registro completo pasado sigue completo")
check(thirty.progress("2026-10-12",[pastReading]).ratio == reading.progress("2026-10-12",[pastReading]).ratio,"Mantiene el porcentaje pasado")
var forty = thirty; forty.goal = 40; forty = forty.preservingMetrics(from:thirty,effectiveDate:"2026-10-21")
check(forty.at("2026-10-20").goal == 30 && forty.at("2026-10-21").goal == 40,"Permite escalonar metas futuras")
var named = forty; named.name = "Leer cada día"; named = named.preservingMetrics(from:forty,effectiveDate:"2026-10-15")
check(named.metricHistory == forty.metricHistory,"Editar el nombre no altera las metas")
var hours = forty; hours.unit = "hr"; hours.goal = 1; hours = hours.preservingMetrics(from:forty,effectiveDate:"2026-10-28")
check(hours.at("2026-10-12").unit == "min" && hours.at("2026-10-28").unit == "hr","Cambiar unidad no reinterpreta minutos anteriores")
let historyBackup = try readBackup(JSONEncoder().encode(Snapshot(habits:[hours],entries:[pastReading])))
check(historyBackup.habits[0].metricHistory == hours.metricHistory && historyBackup.entries[0].note == pastReading.note,"La copia conserva metas y notas")
var weekdays = hours; weekdays.frequency = "weekdays"; weekdays.days = [1]; weekdays = weekdays.preservingMetrics(from:hours,effectiveDate:"2026-11-01")
check(weekdays.scheduled("2026-10-13") && !weekdays.scheduled("2026-11-03"),"La nueva frecuencia respeta los días anteriores")
check(rangeTotals([thirty],[pastReading],start:"2026-10-12",end:"2026-10-12").1 == 1,"El informe mantiene la meta anterior cumplida")
let historicalWidget = WidgetSnapshot(date:"2026-10-14",habits:[],completion:0,schedules:[forty],records:[WidgetRecord(habitId:reading.id,date:"2026-10-12",value:20,checked:false)]).forDay("2026-10-12")
check(historicalWidget.habits[0].goal == 20 && historicalWidget.habits[0].done,"El widget usa la meta de la fecha")
var sameDay = thirty; sameDay.goal = 35; sameDay = sameDay.preservingMetrics(from:thirty,effectiveDate:"2026-10-14")
check(sameDay.metricHistory?.count == 2 && sameDay.at("2026-10-13").goal == 20,"Editar dos veces hoy preserva la base histórica")
var weeklyBefore = reading; weeklyBefore.period = "week"; weeklyBefore.goal = 60
var weeklyAfter = weeklyBefore; weeklyAfter.unit = "hr"; weeklyAfter.goal = 1; weeklyAfter = weeklyAfter.preservingMetrics(from:weeklyBefore,effectiveDate:"2026-10-14")
let mixed = [Entry(habitId:reading.id,date:"2026-10-12",value:60),Entry(habitId:reading.id,date:"2026-10-14",value:1)]
check(weeklyAfter.progress("2026-10-13",mixed).value == 60 && weeklyAfter.progress("2026-10-14",mixed).value == 1,"No suma unidades de versiones diferentes en la misma semana")
let oldHabitData = try JSONEncoder().encode(reading)
let oldHabitDecoded = try JSONDecoder().decode(Habit.self,from:oldHabitData)
check(oldHabitDecoded.metricHistory == nil,"Los hábitos anteriores siguen siendo compatibles")
var badHistory = thirty; badHistory.metricHistory![0].metric.goal = -1
do { _ = try readBackup(JSONEncoder().encode(Snapshot(habits:[badHistory]))); fatalError("Aceptó una meta histórica inválida") } catch { }
print("15 comprobaciones de metas por fecha, unidades, informes, widgets y copias: correctas")
var filterHabit = Habit(); filterHabit.name = "Filtro"; filterHabit.startDate = "2026-10-01"; filterHabit.goal = 20; filterHabit.unit = "min"
let filterDate = "2026-10-14"
let partialFilterEntries = [Entry(habitId:filterHabit.id,date:filterDate,value:10)]
let completeFilterEntries = [Entry(habitId:filterHabit.id,date:filterDate,value:20)]
check(HabitDayFilter().matches(filterHabit,date:filterDate,entries:partialFilterEntries,hour:15),"Todos incluye progreso parcial")
check(HabitDayFilter(status:.unmet).matches(filterHabit,date:filterDate,entries:partialFilterEntries,hour:15),"Pendientes incluye metas incompletas")
check(!HabitDayFilter(status:.met).matches(filterHabit,date:filterDate,entries:partialFilterEntries,hour:15),"Completados excluye progreso parcial")
check(HabitDayFilter(status:.met).matches(filterHabit,date:filterDate,entries:completeFilterEntries,hour:15),"Completados usa el progreso real")
check(!HabitDayFilter(status:.unmet).matches(filterHabit,date:filterDate,entries:completeFilterEntries,hour:15),"Pendientes excluye metas completadas")
check(HabitDayFilter(time:.now).matches(filterHabit,date:filterDate,entries:[],hour:15),"Ahora incluye cualquier hora")
filterHabit.timeOfDay = "morning"
check(HabitDayFilter(time:.now).matches(filterHabit,date:filterDate,entries:[],hour:9),"Ahora incluye la franja actual")
check(!HabitDayFilter(time:.now).matches(filterHabit,date:filterDate,entries:[],hour:15),"Ahora excluye otra franja")
check(!HabitDayFilter(time:.any).matches(filterHabit,date:filterDate,entries:[],hour:9),"Cualquier hora no incluye mañana")
check(HabitDayFilter(status:.met,time:.morning).matches(filterHabit,date:filterDate,entries:completeFilterEntries,hour:15),"Combina estado y franja sin depender del reloj")
check(!HabitDayFilter().matches(filterHabit,date:"2026-09-30",entries:[],hour:15),"Filtrar no muestra hábitos anteriores a su inicio")
check(HabitDayFilter(status:.met).matches(thirty,date:"2026-10-12",entries:[pastReading],hour:15),"El filtro respeta la meta histórica")
print("12 comprobaciones de filtros combinados, horario y metas históricas: correctas")

// iCloud reconciliation: no network, Apple account or real Health data is used.
var cloudHabit = reading
let cloudDay = "2026-10-14"
let cloudEntry = Entry(habitId:cloudHabit.id,date:cloudDay,value:3,note:"Nota de prueba")
var offline = SavedState(snapshot:Snapshot(habits:[cloudHabit],entries:[cloudEntry]),queue:[Operation(op:"entry",id:cloudHabit.id,date:cloudDay,mode:"increment",value:3)])
var replica = CloudReplica()
replica.incorporate(offline)
check(replica.snapshot.entries[0].value == 3,"Primer envío no duplica incrementos ya reflejados localmente")
check(replica.receipts.contains(offline.queue[0].requestId),"El primer envío registra recibos estables")
offline.cloud = CloudLink(accountID:"synthetic-account",epoch:replica.epoch,lastSync:Date())
replica.incorporate(offline)
check(replica.snapshot.entries[0].value == 3,"Reintentar después de fallo local no duplica el envío confirmado")
let plus = Operation(op:"entry",id:cloudHabit.id,date:cloudDay,mode:"increment",value:2)
offline.queue = [plus]
replica.incorporate(offline)
check(replica.snapshot.entries[0].value == 5,"Aplica una operación nueva sobre el estado remoto")
replica.incorporate(offline)
check(replica.snapshot.entries[0].value == 5,"Repetir el mismo identificador es idempotente")
check(replica.snapshot.entries[0].note == cloudEntry.note,"El incremento conserva la nota")
var futureCloudHabit = cloudHabit; futureCloudHabit.goal = 50
futureCloudHabit = futureCloudHabit.preservingMetrics(from:cloudHabit,effectiveDate:"2026-10-20")
offline.queue = [Operation(op:"habit",habit:futureCloudHabit)]
replica.incorporate(offline)
check(replica.snapshot.habits[0].at("2026-10-14").goal == 20 && replica.snapshot.habits[0].at("2026-10-20").goal == 50,"La copia privada conserva versiones de meta")
offline.queue = [Operation(op:"delete",id:cloudHabit.id)]
replica.incorporate(offline)
check(replica.snapshot.habits.isEmpty && replica.snapshot.entries.isEmpty,"El borrado sincronizado elimina hábito y registros")
offline.queue = []
replica.incorporate(offline)
check(replica.snapshot.habits.isEmpty,"Un dispositivo ya vinculado no resucita hábitos eliminados desde su snapshot viejo")
var remoteOnly = Habit(); remoteOnly.name = "Solo remoto"; remoteOnly.startDate = cloudDay
replica.snapshot.habits = [remoteOnly]
offline.cloud = nil
replica.incorporate(offline)
check(replica.snapshot.habits.count == 2,"La primera combinación conserva hábitos remotos distintos")
check(replica.snapshot.entries[0].value == 3,"La combinación inicial conserva el valor local")
let recoveredReplica = try JSONDecoder().decode(CloudReplica.self,from:JSONEncoder().encode(replica))
check(recoveredReplica.epoch == replica.epoch && recoveredReplica.receipts == replica.receipts,"Codificación conserva identidad de copia y recibos")
let oldSavedData = try JSONEncoder().encode(SavedState(snapshot:Snapshot(habits:[cloudHabit])))
var oldSavedObject = try JSONSerialization.jsonObject(with:oldSavedData) as! [String:Any]
oldSavedObject.removeValue(forKey:"cloud")
let oldSaved = try JSONDecoder().decode(SavedState.self,from:JSONSerialization.data(withJSONObject:oldSavedObject))
check(oldSaved.cloud == nil && oldSaved.snapshot.habits[0].id == cloudHabit.id,"Migra el estado anterior sin cuenta iCloud")
var atomicCloud = offline
atomicCloud.cloud = CloudLink(accountID:"synthetic-account",epoch:replica.epoch,lastSync:Date())
try repository.write(atomicCloud)
let storedCloud = try repository.read()
check(storedCloud.cloud?.epoch == replica.epoch && storedCloud.snapshot.habits.count == atomicCloud.snapshot.habits.count,"Estado, cola y vínculo se persisten juntos")
let portable = String(data:try JSONEncoder().encode(atomicCloud.snapshot),encoding:.utf8)!
check(!portable.contains("synthetic-account") && !portable.contains("corrections") && !portable.contains("healthConfiguration"),"La copia portable no incluye cuenta ni configuración de Salud")
print("15 comprobaciones de copia privada, reintentos, historial, borrado y migración: correctas")

var pendingDelete = SavedState(snapshot:Snapshot(),queue:[Operation(op:"delete",id:cloudHabit.id)])
var oldPrivateCopy = CloudReplica(snapshot:Snapshot(habits:[cloudHabit],entries:[cloudEntry]))
oldPrivateCopy.incorporate(pendingDelete)
check(oldPrivateCopy.snapshot.habits.isEmpty && oldPrivateCopy.snapshot.entries.isEmpty,"La primera combinación respeta borrados pendientes del iPhone")
print("1 comprobación adicional de borrado pendiente al activar: correcta")
