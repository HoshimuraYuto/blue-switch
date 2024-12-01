import UserNotifications

/// Protocol defining the interface for managing system notifications
protocol NotificationManaging {
  /// Checks current authorization status and requests if needed
  static func requestAuthorizationIfNeeded()

  /// Requests notification authorization from the user
  static func requestAuthorization()

  /// Displays a notification with the specified title and body
  /// - Parameters:
  ///   - title: The notification title
  ///   - body: The notification message
  static func showNotification(title: String, body: String)
}

final class NotificationManager: NotificationManaging {
  // MARK: - Types & Constants

  private enum Constants {
    static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
  }

  // MARK: - Public Methods

  static func requestAuthorizationIfNeeded() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .notDetermined:
        requestAuthorization()
      case .denied:
        print("User has denied notifications")
      case .authorized, .provisional, .ephemeral:
        print("Notifications are authorized")
      @unknown default:
        print("Unknown notification authorization status")
      }
    }
  }

  static func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(
      options: Constants.authorizationOptions
    ) { granted, error in
      if let error = error {
        print("Failed to request notification authorization: \(error)")
        return
      }
      print("Notification authorization was \(granted ? "granted" : "denied")")
    }
  }

  static func showNotification(title: String, body: String) {
    let content = createNotificationContent(title: title, body: body)
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("Failed to show notification: \(error)")
      }
    }
  }

  // MARK: - Private Methods

  private static func createNotificationContent(title: String, body: String)
    -> UNMutableNotificationContent
  {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    return content
  }
}
