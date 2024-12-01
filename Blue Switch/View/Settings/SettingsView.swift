import SwiftUI

/// Main settings view that handles all application configuration through tab-based navigation
struct SettingsView: View {
  // MARK: - Types

  /// Constants for tab items configuration
  private enum TabItem {
    /// Configuration for each tab
    static let devices = (image: "keyboard", text: "Peripheral")
    static let mac = (image: "desktopcomputer", text: "Device")
    static let general = (image: "gearshape.fill", text: "General")
    static let other = (image: "ellipsis.circle", text: "Other")
  }

  // MARK: - Properties

  /// Window dimensions for the settings view
  private let windowSize = CGSize(width: 600, height: 400)

  // MARK: - View Content

  var body: some View {
    TabView {
      BluetoothPeripheralSettingsView()
        .tabItem {
          Label(TabItem.devices.text, systemImage: TabItem.devices.image)
        }

      NetworkDeviceManagementView()
        .tabItem {
          Label(TabItem.mac.text, systemImage: TabItem.mac.image)
        }

      OtherSettingsView()
        .tabItem {
          Label(TabItem.other.text, systemImage: TabItem.other.image)
        }
    }
    .frame(width: windowSize.width, height: windowSize.height)
  }
}

// MARK: - Preview

#Preview {
  SettingsView()
}
