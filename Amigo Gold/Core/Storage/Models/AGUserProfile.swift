import Foundation
import SwiftData

@Model
final class AGUserProfile {
    @Attribute(.unique) var id: String
    var email: String
    var createdAt: Date

    init(id: String, email: String, createdAt: Date = .now) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
    }
}
