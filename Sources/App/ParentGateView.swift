import LocalAuthentication
import SwiftUI

enum ParentAction: String, Identifiable {
    case start
    case end
    case continueAfterBreak
    case nextRound
    case editAllowedApps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start:
            "开始儿童模式"
        case .end:
            "结束儿童模式"
        case .continueAfterBreak:
            "休息完成"
        case .nextRound:
            "再玩一轮"
        case .editAllowedApps:
            "修改允许 App"
        }
    }
}

struct ParentGateView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var action: ParentAction
    var onVerified: () -> Void

    @StateObject private var biometricAuth = ParentBiometricAuthCoordinator()
    @State private var pin = ""
    @State private var didFail = false
    @State private var isVerified = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.teal)

                Text(action.title)
                    .font(.largeTitle.bold())

                if action == .continueAfterBreak, isVerified {
                    Button {
                        onVerified()
                    } label: {
                        Label("再玩 \(AppConstants.durationText(seconds: model.effectivePlaySeconds))", systemImage: "play.fill")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        model.endChildMode()
                        dismiss()
                    } label: {
                        Label("结束儿童模式", systemImage: "stop.fill")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    if model.settings.prefersBiometrics, biometryTitle != nil {
                        Button {
                            authenticateWithBiometrics()
                        } label: {
                            Label(biometryTitle ?? "生物验证", systemImage: biometryIcon)
                                .frame(maxWidth: 280)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(biometricAuth.isAuthenticating)
                    }

                    SecureField("家长 PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .frame(maxWidth: 320)
                        .onChange(of: pin) { value in
                            pin = String(value.filter(\.isNumber).prefix(6))
                        }

                    if didFail {
                        Text("PIN 不正确。")
                            .foregroundStyle(.red)
                    }

                    Button {
                        guard model.verifyPIN(pin) else {
                            didFail = true
                            return
                        }
                        completeVerification()
                    } label: {
                        Label("验证", systemImage: "checkmark")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!(4...6).contains(pin.count))
                }
            }
            .padding(32)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(biometricAuth.isAuthenticating)
    }

    // MARK: - 生物验证

    private static let biometryInfo: (title: String?, icon: String) = {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return (nil, "faceid")
        }
        switch context.biometryType {
        case .faceID:
            return ("面容 ID", "faceid")
        case .touchID:
            return ("触控 ID", "touchid")
        default:
            return (nil, "faceid")
        }
    }()

    private var biometryTitle: String? {
        Self.biometryInfo.title
    }

    private var biometryIcon: String {
        Self.biometryInfo.icon
    }

    private func authenticateWithBiometrics() {
        Task {
            let success = await biometricAuth.authenticate(reason: "验证家长身份")
            if success {
                completeVerification()
            }
        }
    }

    private func completeVerification() {
        if action == .continueAfterBreak {
            isVerified = true
        } else {
            onVerified()
        }
    }
}
