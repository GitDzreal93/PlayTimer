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
            backgroundBlurStyle: .systemChromeMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.12, blue: 0.14, alpha: 1),
            icon: UIImage(systemName: "pause.circle.fill"),
            title: ShieldConfiguration.Label(text: "该休息一下了", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor(red: 0.82, green: 0.94, blue: 0.92, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "查看休息时间", color: UIColor(red: 0.03, green: 0.10, blue: 0.11, alpha: 1)),
            primaryButtonBackgroundColor: UIColor(red: 0.52, green: 0.93, blue: 0.86, alpha: 1)
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
                return "本轮 \(session.playDurationText) 已经用完。休息到 \(formatter.string(from: breakEndAt))。"
            }
            return "允许 App 的 \(session.playDurationText) 已经用完。休息到 \(formatter.string(from: breakEndAt))。"
        }

        return "本轮 \(session.playDurationText) 已经用完。"
    }
}
