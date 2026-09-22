import Foundation
private final class Owner {
    let queue = DispatchQueue(label: "heartbeat-test")
    let renewed = DispatchSemaphore(value: 0)
    var stopped = false, leaseRequestInFlight = false
    var leaseTimer: DispatchSourceTimer?
    var requests = 0
    func callPath(_ suffix: String) -> String { "/calls/audit/\(suffix)" }
    func request(path: String, method: String, json: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        precondition(path == "/calls/audit/lease" && method == "PUT")
        requests += 1
        completion(.success(()))
        renewed.signal()
    }
    // INSERT_PRODUCT_METHODS
}
@main struct Tests {
    static func main() {
        let c = Owner()
        // No connect() or media/ICE exchange has happened.
        c.startControlHeartbeat(); c.startControlHeartbeat()
        precondition(c.renewed.wait(timeout: .now() + 7) == .success)
        c.queue.sync {
            precondition(c.requests == 1 && !c.leaseRequestInFlight)
            c.stopped = true
            c.leaseTimer?.cancel(); c.leaseTimer = nil
        }
        c.startControlHeartbeat()
        c.queue.sync { precondition(c.leaseTimer == nil) }
    }
}
