import SwiftUI

/// View responsible for managing Bluetooth peripheral device connections and settings
struct BluetoothPeripheralSettingsView: View {
  // MARK: - Dependencies

  @StateObject private var bluetoothStore = BluetoothPeripheralStore.shared

  // MARK: - Constants

  private enum Strings {
    static let removeAll = "Remove All"
    static let noRegistered = "No registered peripherals"
    static let noAvailable = "No available peripherals found"
    static let addDevice = "Add Device"
    static let removeFromPC = "Remove from PC"
    static let connectToPC = "Connect to PC"
    static let removeDevice = "Remove Device"
  }

  // MARK: - View Content

  private var content: some View {
    Form {
      RegisteredPeripheralsSectionView(
        peripherals: bluetoothStore.peripherals,
        onPeripheralToggleConnection: handlePeripheralToggleConnection,
        onPeripheralRemove: handlePeripheralRemove
      )

      AvailablePeripheralsSectionView(
        peripherals: bluetoothStore.availablePeripherals,
        onPeripheralAdd: handlePeripheralAdd
      )
    }
    .onAppear(perform: handleOnAppear)
  }

  var body: some View {
    if #available(macOS 13.0, *) {
      content.formStyle(.grouped)
    } else {
      content
    }
  }

  // MARK: - Private Methods

  private func handlePeripheralToggleConnection(_ peripheral: BluetoothPeripheral) {
    if peripheral.isConnected {
      bluetoothStore.unregisterFromPC(peripheral)
    } else {
      bluetoothStore.connectPeripheral(peripheral)
    }
  }

  private func handlePeripheralRemove(_ peripheral: BluetoothPeripheral) {
    bluetoothStore.removeFromList(peripheral)
  }

  private func handlePeripheralAdd(_ peripheral: BluetoothPeripheral) {
    bluetoothStore.addPeripheral(peripheral)
  }

  private func handleOnAppear() {
    bluetoothStore.fetchConnectedPeripherals()
  }
}

// MARK: - Supporting Views

/// Section for displaying registered Bluetooth peripherals
private struct RegisteredPeripheralsSectionView: View {
  // MARK: - Properties

  let peripherals: [BluetoothPeripheral]
  let onPeripheralToggleConnection: (BluetoothPeripheral) -> Void
  let onPeripheralRemove: (BluetoothPeripheral) -> Void

  var body: some View {
    Section(header: Text("Registered Peripherals")) {
      if peripherals.isEmpty {
        Text("No registered peripherals")
          .foregroundColor(.secondary)
      } else {
        PeripheralListView(
          peripherals: peripherals,
          showConnectionStatus: true,
          primaryAction: onPeripheralToggleConnection,
          secondaryAction: onPeripheralRemove
        )
      }
    }
  }
}

/// Section for displaying available Bluetooth peripherals
private struct AvailablePeripheralsSectionView: View {
  let peripherals: [BluetoothPeripheral]
  let onPeripheralAdd: (BluetoothPeripheral) -> Void

  var body: some View {
    Section(header: Text("Available Peripherals")) {
      if peripherals.isEmpty {
        Text("No available peripherals found")
          .foregroundColor(.secondary)
      } else {
        PeripheralListView(
          peripherals: peripherals,
          showConnectionStatus: false,
          primaryAction: onPeripheralAdd
        )
      }
    }
  }
}

/// List view for displaying Bluetooth peripherals
private struct PeripheralListView: View {
  let peripherals: [BluetoothPeripheral]
  let showConnectionStatus: Bool
  let primaryAction: (BluetoothPeripheral) -> Void
  var secondaryAction: ((BluetoothPeripheral) -> Void)?

  var body: some View {
    List {
      ForEach(peripherals) { peripheral in
        PeripheralRowView(
          peripheral: peripheral,
          showConnectionStatus: showConnectionStatus,
          primaryAction: { primaryAction(peripheral) },
          secondaryAction: secondaryAction.map { action in
            { action(peripheral) }
          }
        )
      }
    }
  }
}

/// Row view for displaying individual Bluetooth peripheral
private struct PeripheralRowView: View {
  let peripheral: BluetoothPeripheral
  let showConnectionStatus: Bool
  let primaryAction: () -> Void
  var secondaryAction: (() -> Void)?

  var body: some View {
    HStack {
      Text(peripheral.name)
      Spacer()
      if showConnectionStatus {
        Button(peripheral.isConnected ? "Remove from PC" : "Connect to PC", action: primaryAction)
        Button(action: { secondaryAction?() }) {
          Image(systemName: "minus.circle")
            .foregroundColor(.red)
        }
      } else {
        Button(action: primaryAction) {
          Image(systemName: "plus.circle")
            .foregroundColor(.blue)
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  BluetoothPeripheralSettingsView()
}
