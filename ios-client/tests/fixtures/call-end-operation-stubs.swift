import Foundation
// INSERT_PRODUCT_METHODS
private enum Failure: Error { case offline }
private final class Harness {
    var sends: [(String, String)] = []
    var sendDone: ((Result<Void, Error>) -> Void)?
    var readDone: ((Result<ModemDeckCallEndOperation.Observation, Error>) -> Void)?
    var scheduled: [() -> Void] = []
    var reads = 0, completed = 0, deferred = 0
    lazy var op = make(waiting: false)
    func make(waiting: Bool) -> ModemDeckCallEndOperation {
        ModemDeckCallEndOperation(verb: "hangup", waitingForAnswer: waiting,
            send: { verb, id, done in self.sends.append((verb, id)); self.sendDone = done },
            read: { done in self.reads += 1; self.readDone = done },
            schedule: { _, work in self.scheduled.append(work) },
            onComplete: { _ in self.completed += 1 },
            onDeferred: { _ in self.deferred += 1 })
    }
    func tick() { precondition(!scheduled.isEmpty); scheduled.removeFirst()() }
}
@main struct Tests {
    static func main() {
        do {
            let h = Harness(); h.op = h.make(waiting: true)
            h.op.start(); h.op.resume()
            precondition(h.sends.isEmpty && h.reads == 0, "end must wait for the answer HTTP response")
            h.op.answerFinished()
            precondition(h.reads == 1 && h.sends.isEmpty)
            h.readDone?(.success(.owned)); h.tick()
            precondition(h.sends.count == 1 && h.sends[0].0 == "hangup")
            h.sendDone?(.success(()))
            precondition(h.completed == 0, "accepted is not confirmed ended")
            h.readDone?(.success(.ended))
            h.op.answerFinished(); h.op.resume()
            precondition(h.completed == 1 && h.sends.count == 1)
        }
        do {
            let h = Harness(); h.op.start()
            h.sendDone?(.failure(Failure.offline))
            h.readDone?(.failure(Failure.offline)); h.tick()
            precondition(h.sends.count == 1, "no blind retry when reconciliation fails")
            h.readDone?(.success(.ringing)); h.tick()
            precondition(h.sends.count == 2 && h.sends[1].0 == "reject")
            precondition(h.sends[0].1 != h.sends[1].1)
            h.sendDone?(.success(())); h.readDone?(.success(.owned)); h.tick()
            precondition(h.sends.count == 2, "do not resend an accepted command while awaiting its snapshot")
            h.readDone?(.success(.ended))
            precondition(h.completed == 1)
        }
        do {
            let h = Harness(); h.op.start(); h.op.pause()
            h.sendDone?(.failure(Failure.offline))
            precondition(h.reads == 0 && h.completed == 0)
            h.op.resume(); h.readDone?(.success(.occupied))
            precondition(h.completed == 1 && h.sends.count == 1, "never hang up another owner")
        }
        do {
            let h = Harness(); h.op.resume() // A persisted intent always reads first.
            for _ in 0..<5 { h.readDone?(.failure(Failure.offline)); h.tick() }
            h.readDone?(.failure(Failure.offline))
            precondition(h.deferred == 1 && h.completed == 0 && h.sends.isEmpty)
            h.op.resume(); h.readDone?(.success(.ended))
            precondition(h.completed == 1)
        }
        do {
            let h = Harness(); h.op.start(); h.sendDone?(.failure(Failure.offline))
            h.readDone?(.success(.owned)); h.op.cancel(); h.tick()
            precondition(h.sends.count == 1 && h.completed == 0, "cancel invalidates scheduled retries")
        }
    }
}
