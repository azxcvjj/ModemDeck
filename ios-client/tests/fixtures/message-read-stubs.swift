import Foundation

struct Message { let id: Int64; let incoming: Bool }
struct Store { var messages: [Message] }
struct Conversation {
    var store: Store
    // INSERT_PRODUCT_METHODS
}

@main struct ReadReceiptRegression {
    static func main() {
        var conversation = Conversation(store: Store(messages: []))
        precondition(conversation.readThroughMessageID == nil)
        precondition(conversation.newestIncomingMessageID == nil)
        // Timestamp order places the newly imported old SMS first.
        conversation.store.messages = [Message(id: 243, incoming: true), Message(id: 228, incoming: true)]
        let acknowledged = conversation.readThroughMessageID!
        precondition(acknowledged == 243)
        precondition(!conversation.store.messages.contains { $0.incoming && $0.id > acknowledged })
        // A later arrival with an older timestamp must stay unread while the
        // previous receipt is in flight, until a new acknowledgement succeeds.
        conversation.store.messages.insert(Message(id: 250, incoming: true), at: 0)
        precondition(conversation.newestIncomingMessageID! > acknowledged)
        precondition(conversation.readThroughMessageID == 250)
        conversation.store.messages.append(Message(id: 251, incoming: false))
        precondition(conversation.readThroughMessageID == 251)
        precondition(conversation.newestIncomingMessageID == 250)
    }
}
