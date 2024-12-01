import SwiftUI

/// View responsible for managing general application configuration settings
struct GeneralSettingsView: View {
  // MARK: - Constants

  private enum Strings {
    static let autoLaunch = "Auto Launch at Startup"
    static let notifications = "Enable Notifications"
    static let updates = "Automatic Updates"
  }

  // MARK: - Properties

  @AppStorage("autoLaunch") private var autoLaunch = false
  @AppStorage("notificationsEnabled") private var notificationsEnabled = true
  @AppStorage("autoUpdate") private var autoUpdate = true

  // MARK: - View Content

  /// Computed property that provides form content
  private var formContent: some View {
    Form {
      Section {
        Toggle(Strings.autoLaunch, isOn: $autoLaunch)
        Toggle(Strings.notifications, isOn: $notificationsEnabled)
        Toggle(Strings.updates, isOn: $autoUpdate)
      }
    }
  }

  var body: some View {
    if #available(macOS 13.0, *) {
      formContent
        .formStyle(.grouped)
    } else {
      formContent
        .padding()
    }
  }
}

// MARK: - Preview

#Preview {
  GeneralSettingsView()
}
