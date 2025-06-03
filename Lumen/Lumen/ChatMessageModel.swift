import Foundation
import SwiftData

@Model
final class ChatMessageModel {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var roleValue: String = "user"
    var content: String = ""

    enum Role: String {
        case user, assistant
    }

    @Transient
    var role: Role {
        Role(rawValue: roleValue) ?? .user
    }

    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         role: Role = .user,
         content: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.roleValue = role.rawValue
        self.content = content
    }
}
