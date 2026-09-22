import Foundation
struct ModemDeckRuntimeCallState { let id: String; let revision: Int64; let controlState: String }
final class Cursor {
    var runtimeCallGeneration = 2
    var runtimeCallRevision: Int64 = -1
    var runtimeCallRetryAttempt = 0
    var accepted: [String] = []
    func reconcileRuntimeCall(_ state: ModemDeckRuntimeCallState) { accepted.append(state.controlState) }
    // INSERT_PRODUCT_METHODS
}
@main struct Tests {
    static func main() {
        let c = Cursor()
        for (revision, owner, generation, id) in [(7, "available", 2, "call"), (7, "occupied", 2, "call"),
                                                 (6, "owned", 2, "call"), (8, "owned", 1, "call"), (8, "owned", 2, "other")] {
            c.acceptRuntimeCallState(.init(id: id, revision: Int64(revision), controlState: owner), callID: "call", generation: generation)
        }
        precondition(c.accepted == ["available", "occupied"])
    }
}
