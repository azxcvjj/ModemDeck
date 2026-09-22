import Foundation
import CryptoKit
private final class Operation {
    var resumed = 0, cancelled = false
    func resume() { resumed += 1 }
    func cancel() { cancelled = true }
}
// INSERT_PRODUCT_METHODS
@main struct Tests {
    static func main() throws {
        let old = ModemDeckCredential(serverURL: "https://example.invalid", token: "old")
        let current = ModemDeckCredential(serverURL: "https://example.invalid", token: "current")
        let first = ModemDeckCallEndIntent(uuid: UUID(), callID: "call-1", verb: "reject", scope: current.callControlScope)
        let foreign = ModemDeckCallEndIntent(uuid: UUID(), callID: "call-2", verb: "hangup", scope: old.callControlScope)
        let data = try JSONEncoder().encode([first, foreign])
        precondition(!String(decoding: data, as: UTF8.self).contains("token"))
        let c = Recovery()
        for intent in try JSONDecoder().decode([ModemDeckCallEndIntent].self, from: data) { c.pendingEndIntents[intent.uuid] = intent }
        c.resumePendingCallEnds(); precondition(c.installed.isEmpty)
        let previous = Operation()
        c.pendingCallEnds[foreign.uuid] = previous
        c.credential = current
        c.resumePendingCallEnds()
        precondition(c.installed == [first.uuid] && c.remembered == [first.uuid])
        c.resumePendingCallEnds()
        precondition(c.installed.count == 1 && c.pendingCallEnds[first.uuid]?.resumed == 1)
        precondition(c.pendingCallEnds[foreign.uuid] == nil && previous.cancelled)
    }
}
