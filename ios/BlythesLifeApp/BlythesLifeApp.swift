import SwiftUI
import BlythesLifeUI
#if canImport(UserNotifications)
import UserNotifications
#endif

#if canImport(UserNotifications)
private final class BlythesLifeNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = BlythesLifeNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.notification.request.content.userInfo["kind"] as? String == "pump" {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("BlythesLifeOpenLogSheet"),
                    object: nil,
                    userInfo: ["kind": "pump"]
                )
            }
        }
    }
}
#endif

@main
struct BlythesLifeApp: App {
    init() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().delegate = BlythesLifeNotificationDelegate.shared
        #endif
    }

    var body: some Scene {
        WindowGroup {
            BlythesLifeRootView()
        }
    }
}
