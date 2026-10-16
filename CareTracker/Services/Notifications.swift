import Foundation
import UserNotifications

/// Локальные уведомления: «Сделала», «Через 30 минут», «Сегодня пропускаю».
/// План строит NotificationPlanner (Core), здесь — только раскладка по iOS.
@MainActor
final class Notifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifications()
    weak var store: AppStore?
    private let center = UNUserNotificationCenter.current()

    func setup(store: AppStore) {
        self.store = store
        center.delegate = self
        let done = UNNotificationAction(identifier: "done", title: "Сделала", options: [])
        let snooze = UNNotificationAction(identifier: "snooze", title: "Через 30 минут", options: [])
        let skip = UNNotificationAction(identifier: "skip", title: "Сегодня пропускаю", options: [.destructive])
        center.setNotificationCategories([UNNotificationCategory(identifier: "ROUTINE", actions: [done, snooze, skip], intentIdentifiers: [], options: [])])
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func reschedule(_ state: AppState, now: Date = Date()) {
        let today = Days.key(now)
        let plan = NotificationPlanner.plan(state, today: today, now: Days.hhmm(now))
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix("m-") || $0.hasPrefix("e-") || $0.hasPrefix("f-") }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)
            for r in plan {
                let (y, m, d) = Days.parts(r.day)
                let hm = r.time.split(separator: ":").compactMap { Int($0) }
                guard hm.count == 2 else { continue }
                let content = UNMutableNotificationContent()
                content.title = r.title
                content.body = r.body
                content.sound = .default
                content.categoryIdentifier = "ROUTINE"
                content.threadIdentifier = r.kind
                content.userInfo = ["day": r.day, "kind": r.kind]
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(year: y, month: m, day: d, hour: hm[0], minute: hm[1]), repeats: false)
                self.center.add(UNNotificationRequest(identifier: r.id, content: content, trigger: trigger))
            }
        }
    }

    // Показ, когда приложение открыто.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Действия из уведомления.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let day = info["day"] as? String ?? Days.key()
        let kind = info["kind"] as? String ?? "evening"
        let action = response.actionIdentifier
        let content = response.notification.request.content
        await MainActor.run {
            switch action {
            case "done": self.store?.markBlock(kind: kind, day: day)
            case "skip": self.store?.skipBlock(kind: kind, day: day)
            case "snooze":
                let c = UNMutableNotificationContent()
                c.title = content.title; c.body = content.body; c.sound = .default; c.categoryIdentifier = "ROUTINE"; c.userInfo = content.userInfo
                self.center.add(UNNotificationRequest(identifier: "snooze-\(Ids.make())", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)))
            default: self.store?.route = .today
            }
        }
    }
}
