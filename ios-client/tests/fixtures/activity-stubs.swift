import Foundation

struct ModemDeckMessageThread: Equatable {
    let id: String
    let lastTimestamp: String
    var unreadCount = 0
    var markedUnread = false
    var favorite = false
}
struct ModemDeckCallRecord: Equatable {
    let id: String
    let startedAt: String
    var missed = false
    var read = true
    var favorite = false
}
enum ModemDeckRoute: Hashable { case message(String), call(String) }

// INSERT_PRODUCT_METHODS

@main struct Verification {
    static func main() {
        let threads = [
            ModemDeckMessageThread(id: "utc", lastTimestamp: "2026-09-05T08:00:00Z"),
            ModemDeckMessageThread(id: "offset", lastTimestamp: "2026-09-05T17:01:00+09:00"),
            ModemDeckMessageThread(id: "fraction", lastTimestamp: "2026-09-05T08:00:00.500Z"),
            ModemDeckMessageThread(id: "invalid", lastTimestamp: "")
        ]
        let calls = (0..<3000).map { index in
            ModemDeckCallRecord(id: "history-\(index)", startedAt: Date(timeIntervalSince1970: 1_700_000_000 - Double(index * 86400)).ISO8601Format())
        }
        let snapshot = ModemDeckActivitySnapshot.build(.init(threads: threads, calls: calls))
        let items = snapshot.days.flatMap(\.items)
        precondition(items.count == 3004 && snapshot.routes.count == 3004, "Historical rows were dropped or duplicated")
        precondition(items.prefix(3).map(\.id) == ["message-offset", "message-fraction", "message-utc"], "Time zones or subsecond ordering regressed")
        precondition(items.last?.id == "message-invalid")
        precondition(snapshot.days.map(\.id) == snapshot.days.map(\.id).sorted(by: >))
        let tied = ModemDeckActivitySource(threads: [threads[0]], calls: [.init(id: "tie", startedAt: threads[0].lastTimestamp)])
        precondition(ModemDeckActivitySnapshot.build(tied).days.flatMap(\.items).map(\.id) == ["call-tie", "message-utc"])
        precondition(ModemDeckActivitySnapshot.build(.init(threads: [], calls: [])).days.isEmpty)
        print("Activity history, timezone ordering, ties and empty snapshots passed")
    }
}
