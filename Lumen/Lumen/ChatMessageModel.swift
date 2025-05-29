
import Foundation
import SwiftData

@Model
final class ChatMessageModel {
    var id: UUID
    var timestamp: Date
    var roleValue: String
    var content: String

    enum Role: String {
        case user, assistant
    }

    var role: Role {
        return Role(rawValue: roleValue) ?? .user
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), role: Role, content: String) {
        self.id = id
        self.timestamp = timestamp
        self.roleValue = role.rawValue
        self.content = content
    }
}
