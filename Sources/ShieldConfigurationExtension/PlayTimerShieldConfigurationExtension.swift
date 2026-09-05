import ManagedSettings
import ManagedSettingsUI
import UIKit

final class PlayTimerShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    private func configuration() -> ShieldConfiguration {
        let session = SharedStateStore.shared.loadSession()
        let subtitle = subtitleText(for: session)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(red: 0.95, green: 0.98, blue: 0.97, alpha: 1),
            icon: UIImage(systemName: "pause.circle.fill"),
            title: ShieldConfiguration.Label(text: "该休息一下了", color: .label),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "查看休息时间", color: .white),
            primaryButtonBackgroundColor: UIColor.systemTeal
        )
    }

    private func subtitleText(for session: PlaySession?) -> String {
        guard let session else {
            return "本轮时间已经用完。"
        }

        if let breakEndAt = session.breakEndAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if session.allowedApplicationCount == 0 {
                return "本轮 \(session.playDurationMinutes) 分钟已经用完。休息到 \(formatter.string(from: breakEndAt))。"
            }
            return "允许 App 的 \(session.playDurationMinutes) 分钟已经用完。休息到 \(formatter.string(from: breakEndAt))。"
        }

        return "本轮 \(session.playDurationMinutes) 分钟已经用完。"
    }
}
