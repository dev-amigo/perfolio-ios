//
//  Amigo_GoldApp.swift
//  Amigo Gold
//
//  Created by Tirupati Balan on 12/11/25.
//

import SwiftUI
import SwiftData

@main
struct Amigo_GoldApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var privyCoordinator = PrivyAuthCoordinator.shared
    private let swiftDataStack = SwiftDataStack()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(themeManager)
                .environmentObject(privyCoordinator)
                .environment(\.colorScheme, themeManager.colorScheme)
                .environment(\.locale, LocalizationManager.shared.locale)
        }
        .modelContainer(swiftDataStack.container)
    }
}
