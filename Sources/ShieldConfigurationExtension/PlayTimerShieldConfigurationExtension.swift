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
        let isWaitingForParent = session?.phase == .waitingParent
        let catImage = UIImage(named: "blue-cat-resting", in: Bundle.main, compatibleWith: nil)

        return ShieldConfiguration(
            backgroundColor: UIColor(red: 1, green: 0.86, blue: 0.73, alpha: 1),
            icon: catImage,
            title: ShieldConfiguration.Label(
                text: isWaitingForParent ? "休息结束啦" : "眼睛也要休息啦",
                color: UIColor(red: 0.12, green: 0.24, blue: 0.29, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: isWaitingForParent ? "快去找你的爸爸妈妈吧。" : breakText(for: session),
                color: UIColor(red: 0.20, green: 0.32, blue: 0.35, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: isWaitingForParent ? "知道了" : "继续休息",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.05, green: 0.45, blue: 0.46, alpha: 1)
        )
    }

    private func breakText(for session: PlaySession?) -> String {
        guard let end = session?.breakEndAt else { return "放下 iPad，喝口水，看看远处。" }
        let remaining = max(0, Int(ceil(end.timeIntervalSinceNow)))
        let clock = String(format: "%02d:%02d", remaining / 60, remaining % 60)
        let endTime = DateFormatter.localizedString(from: end, dateStyle: .none, timeStyle: .short)
        return "还要休息 \(clock) · 休息到 \(endTime)"
    }
}
