import Foundation
import SwiftUI

enum L10n {
    static func text(_ key: Key) -> LocalizedStringKey {
        LocalizedStringKey(key.rawValue)
    }

    static func string(_ key: Key) -> String {
        NSLocalizedString(key.rawValue, comment: "")
    }

    enum Key: String {
        case splashTitle = "splash.title"
        case landingTitle = "landing.title"
        case landingSubtitle = "landing.subtitle"
        case landingCTA = "landing.cta"
        case landingCTALoading = "landing.cta.loading"
        case landingAlertSuccessTitle = "landing.alert.success.title"
        case landingAlertSuccessMessage = "landing.alert.success.message"
        case landingAlertErrorTitle = "landing.alert.error.title"
        case landingAlertErrorMessage = "landing.alert.error.message"
        case landingEnvironmentBadge = "landing.environment.badge"
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    @Published var locale: Locale

    private init(locale: Locale = .current) {
        self.locale = locale
    }

    func update(localeIdentifier: String) {
        guard locale.identifier != localeIdentifier else { return }
        locale = Locale(identifier: localeIdentifier)
    }
}
