import Foundation
import SwiftUI

extension Bundle {
    func string(forInfoDictionaryKey key: String) -> String? {
        object(forInfoDictionaryKey: key) as? String
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

extension Color {
    static let agBlack = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let agOffWhite = Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255)
}

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: padding))
        }
        self.init(base64Encoded: base64)
    }
}
