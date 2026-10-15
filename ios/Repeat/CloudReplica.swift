import Foundation

// Only the portable snapshot enters this envelope. HealthConfiguration, cookies,
// drafts, widget summaries and timer sessions are never cloud inputs.
struct CloudReplica: Codable {
    var version = 1
    var epoch = UUID().uuidString.lowercased()
    var snapshot = Snapshot()
    var receipts = Set<String>()

    mutating func incorporate(_ local:SavedState) {
        if local.cloud == nil {
            // First opt-in is an explicit merge. The UI explains that local values
            // win collisions; the snapshot already contains queued increments.
            let habits = Set(local.snapshot.habits.map(\.id))
            let entries = Set(local.snapshot.entries.map(\.id))
            let moods = Set(local.snapshot.moods.map(\.id))
            snapshot.habits.removeAll { habits.contains($0.id) }
            snapshot.entries.removeAll { entries.contains($0.id) }
            snapshot.moods.removeAll { moods.contains($0.id) }
            snapshot.habits += local.snapshot.habits
            snapshot.entries += local.snapshot.entries
            snapshot.moods += local.snapshot.moods
            // Missing local rows do not encode a queued deletion; replay those
            // explicitly so first opt-in cannot revive a remotely stored habit.
            for operation in local.queue where operation.op == "delete" { snapshot.apply(operation) }
            receipts.formUnion(local.queue.map(\.requestId))
        } else {
            for operation in local.queue where !receipts.contains(operation.requestId) {
                snapshot.apply(operation)
                receipts.insert(operation.requestId)
            }
        }
    }
}
