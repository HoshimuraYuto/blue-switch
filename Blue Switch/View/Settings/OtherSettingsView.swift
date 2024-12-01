import SwiftUI

/// View responsible for displaying and managing miscellaneous application settings
struct OtherSettingsView: View {
  // MARK: - Properties

  @State private var showAlert = false
  @State private var showSheet = false

  @Environment(\.openURL) private var openURL

  // MARK: - View Content

  /// Form content containing setting options
  private var formContent: some View {
    Form {
      Section {
        SettingsRowView(title: "License Information", action: showLicenseInfo)
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

  // MARK: - Private Methods

  private func showLicenseInfo() {
    openURL(URL(string: "https://github.com/HoshimuraYuto/Blue-Switch/blob/main/LICENSE")!)
  }
}

// MARK: - Supporting Views

/// A reusable row component for settings items
private struct SettingsRowView: View {
  // MARK: - Properties

  let title: String
  let action: () -> Void

  // MARK: - View Content

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview {
  OtherSettingsView()
}
