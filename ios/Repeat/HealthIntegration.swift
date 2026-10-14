import Foundation
import HealthKit

struct HealthSource: Identifiable, Hashable {
    var id:String; var title:String; var unit:String; var kind:String
    static let all: [HealthSource] = [
        .init(id:"steps",title:"Pasos",unit:"pasos",kind:HKQuantityTypeIdentifier.stepCount.rawValue),
        .init(id:"distance",title:"Caminar y correr",unit:"km",kind:HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue),
        .init(id:"energy",title:"Energía activa",unit:"Cal",kind:HKQuantityTypeIdentifier.activeEnergyBurned.rawValue),
        .init(id:"exercise",title:"Tiempo de ejercicio",unit:"min",kind:HKQuantityTypeIdentifier.appleExerciseTime.rawValue),
        .init(id:"water",title:"Agua",unit:"ml",kind:HKQuantityTypeIdentifier.dietaryWater.rawValue),
        .init(id:"weight",title:"Peso",unit:"kg",kind:HKQuantityTypeIdentifier.bodyMass.rawValue),
        .init(id:"sleep",title:"Tiempo dormido",unit:"hr",kind:HKCategoryTypeIdentifier.sleepAnalysis.rawValue),
        .init(id:"mindful",title:"Atención plena",unit:"min",kind:HKCategoryTypeIdentifier.mindfulSession.rawValue),
        .init(id:"stand",title:"Minutos de pie",unit:"min",kind:HKQuantityTypeIdentifier.appleStandTime.rawValue),
        .init(id:"sun",title:"Tiempo al sol",unit:"min",kind:HKQuantityTypeIdentifier.timeInDaylight.rawValue)
    ]
    var sampleType: HKSampleType? { HKObjectType.quantityType(forIdentifier:HKQuantityTypeIdentifier(rawValue:kind)) ?? HKObjectType.categoryType(forIdentifier:HKCategoryTypeIdentifier(rawValue:kind)) }
    var healthUnit: HKUnit { switch unit { case "km":return .meterUnit(with:.kilo);case "Cal":return .kilocalorie();case "min":return .minute();case "ml":return .literUnit(with:.milli);case "kg":return .gramUnit(with:.kilo);default:return .count() } }
}
@MainActor
final class HealthIntegration {
    private let health = HKHealthStore()
    var available:Bool { HKHealthStore.isHealthDataAvailable() }
    func request(_ source:HealthSource) async throws {
        guard available,let type = source.sampleType else { throw BackupError.invalid("Apple Health no está disponible para este dato.") }
        try await health.requestAuthorization(toShare:[],read:[type])
    }
    func value(_ source:HealthSource,date:String) async throws -> Double? {
        guard available,let type = source.sampleType else { return nil }
        let calendar = Calendar.current; let start = calendar.startOfDay(for:Day.date(date)); let end = calendar.date(byAdding:.day,value:1,to:start)!
        let predicate = HKQuery.predicateForSamples(withStart:start,end:end,options:[])
        if source.id == "sleep" || source.id == "mindful" {
            let samples:[HKSample] = try await withCheckedThrowingContinuation { continuation in
                health.execute(HKSampleQuery(sampleType:type,predicate:predicate,limit:HKObjectQueryNoLimit,sortDescriptors:nil) { _,samples,error in if let error { continuation.resume(throwing:error) } else { continuation.resume(returning:samples ?? []) } })
            }
            let asleep:Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,HKCategoryValueSleepAnalysis.asleepCore.rawValue,HKCategoryValueSleepAnalysis.asleepDeep.rawValue,HKCategoryValueSleepAnalysis.asleepREM.rawValue]
            let ranges = samples.compactMap { sample -> (Date,Date)? in
                if source.id == "sleep",let category = sample as? HKCategorySample,!asleep.contains(category.value) { return nil }
                let a = max(start,sample.startDate),b = min(end,sample.endDate); return b > a ? (a,b) : nil
            }
            return mergedSeconds(ranges) / (source.id == "sleep" ? 3600 : 60)
        }
        guard let quantity = type as? HKQuantityType else { return nil }
        if source.id == "weight" {
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType:quantity,predicate:predicate,limit:1,sortDescriptors:[NSSortDescriptor(key:HKSampleSortIdentifierEndDate,ascending:false)]) { _,samples,error in
                    if let error { continuation.resume(throwing:error) } else { continuation.resume(returning:(samples?.first as? HKQuantitySample)?.quantity.doubleValue(for:source.healthUnit)) }
                }; health.execute(query)
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType:quantity,quantitySamplePredicate:predicate,options:.cumulativeSum) { _,statistics,error in
                if let error { continuation.resume(throwing:error) } else { continuation.resume(returning:statistics?.sumQuantity()?.doubleValue(for:source.healthUnit)) }
            }; health.execute(query)
        }
    }
}
func mergedSeconds(_ intervals:[(Date,Date)]) -> Double {
    let sorted = intervals.sorted{$0.0 < $1.0}; guard var current = sorted.first else { return 0 }; var seconds:Double = 0
    for next in sorted.dropFirst() { if next.0 <= current.1 { current.1 = max(current.1,next.1) } else { seconds += current.1.timeIntervalSince(current.0); current = next } }
    return seconds + current.1.timeIntervalSince(current.0)
}
