import SwiftUI

private enum Constants {
  enum Strings {
    static let connectedDevices = "Connected Devices"
    static let availableDevices = "Available Devices"
    static let noConnectedDevices = "No connected devices"
    static let noAvailableDevices = "No available devices found"
    static let removeAll = "Remove All"
    static let notify = "Notify"
    static let connect = "Connect"
    static let connectionLimitMessage =
      "Only one device can be connected at a time. Please remove existing device first."
  }

  enum Messages {
    static let deviceGreeting = "Hello, %@!"
  }
}

/// View for managing network device connections and registrations
struct NetworkDeviceManagementView: View {
  // MARK: - Dependencies

  @ObservedObject private var networkStore = NetworkDeviceStore.shared

  // MARK: - View Content

  private var formContent: some View {
    Form {
      RegisteredDevicesSectionView(
        devices: networkStore.networkDevices,
        onDeviceNotify: handleDeviceNotification,
        onDeviceRemove: networkStore.removeNetworkDevice
      )

      AvailableDevicesSectionView(
        devices: networkStore.availableNetworkDevices,
        onDeviceRegister: handleDeviceRegistration
      )
    }
  }

  var body: some View {
    if #available(macOS 13.0, *) {
      formContent
        .formStyle(.grouped)
    } else {
      formContent
    }
  }

  // MARK: - Private Methods

  private func handleDeviceNotification(_ device: NetworkDevice) {
    networkStore.sendNotification(to: device)
  }

  private func handleRemoveAllDevices() {
    networkStore.networkDevices.forEach {
      networkStore.removeNetworkDevice(device: $0)
    }
  }

  private func handleDeviceRegistration(_ device: NetworkDevice) {
    networkStore.registerNetworkDevice(device: device)
  }
}

// MARK: - Supporting Views

private struct RegisteredDevicesSectionView: View {
  // MARK: - Dependencies
  @ObservedObject private var bluetoothStore = BluetoothPeripheralStore.shared
  @ObservedObject private var networkStore = NetworkDeviceStore.shared

  // MARK: - Properties
  let devices: [NetworkDevice]
  let onDeviceNotify: (NetworkDevice) -> Void
  let onDeviceRemove: (NetworkDevice) -> Void

  var body: some View {
    Section {
      if devices.isEmpty {
        Text(Constants.Strings.noConnectedDevices)
          .foregroundColor(.secondary)
      } else {
        NetworkDeviceListView(
          devices: devices,
          buttonTitle: Constants.Strings.notify,
          action: onDeviceNotify,
          onDelete: onDeviceRemove,
          onSyncPeripherals: { device in
            networkStore.sendPeripheralSync(
              peripherals: bluetoothStore.peripherals,
              to: device
            )
          }
        )
      }
    } header: {
      Text(Constants.Strings.connectedDevices)
        .font(.headline)
    }
  }
}

private struct AvailableDevicesSectionView: View {
  // MARK: - Dependencies

  @ObservedObject private var networkStore = NetworkDeviceStore.shared

  // MARK: - Properties

  let devices: [NetworkDevice]
  let onDeviceRegister: (NetworkDevice) -> Void

  var body: some View {
    Section(header: Text(Constants.Strings.availableDevices).font(.headline)) {
      if !self.networkStore.networkDevices.isEmpty {
        Text(Constants.Strings.connectionLimitMessage)
          .foregroundColor(.secondary)
      } else if devices.isEmpty {
        Text(Constants.Strings.noAvailableDevices)
          .foregroundColor(.secondary)
      } else {
        NetworkDeviceListView(
          devices: devices,
          buttonTitle: Constants.Strings.connect,
          action: onDeviceRegister
        )
      }
    }
  }
}

private struct NetworkDeviceListView: View {
  // MARK: - Properties

  let devices: [NetworkDevice]
  let buttonTitle: String
  let action: (NetworkDevice) -> Void
  let onDelete: ((NetworkDevice) -> Void)?
  let onSyncPeripherals: ((NetworkDevice) -> Void)?

  init(
    devices: [NetworkDevice],
    buttonTitle: String,
    action: @escaping (NetworkDevice) -> Void,
    onDelete: ((NetworkDevice) -> Void)? = nil,
    onSyncPeripherals: ((NetworkDevice) -> Void)? = nil
  ) {
    self.devices = devices
    self.buttonTitle = buttonTitle
    self.action = action
    self.onDelete = onDelete
    self.onSyncPeripherals = onSyncPeripherals
  }

  var body: some View {
    List(devices) { device in
      HStack {
        Text(device.name)
        Spacer()
        Button(action: { action(device) }) {
          Text(buttonTitle)
        }
        .disabled(!device.isActive)

        if let onSync = onSyncPeripherals {
          Button(action: { onSync(device) }) {
            Image(systemName: "arrow.triangle.2.circlepath")
              .foregroundColor(.blue)
          }
          .disabled(!device.isActive)
        }

        if let onDelete = onDelete {
          Button(action: { onDelete(device) }) {
            Image(systemName: "trash")
              .foregroundColor(.red)
          }
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  NetworkDeviceManagementView()
}
