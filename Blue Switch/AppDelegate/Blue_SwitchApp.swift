import SwiftUI

/// Main application entry point and configuration
@main
struct Blue_SwitchApp: App {
  // MARK: - Dependencies

  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  // MARK: - Scene Configuration

  var body: some Scene {
    #if os(macOS)
      Settings {
        SettingsView()
      }
    #endif
  }
}
