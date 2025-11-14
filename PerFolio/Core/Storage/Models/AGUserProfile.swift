import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class AGUserProfile {
    @Attribute(.unique) var id: String
    var email: String
    var walletAddress: String?
    var createdAt: Date
    var lastSyncedAt: Date?

    init(id: String, email: String, walletAddress: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.email = email
        self.walletAddress = walletAddress
        self.createdAt = createdAt
        self.lastSyncedAt = nil
    }
}
