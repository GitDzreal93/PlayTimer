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
                        dismiss()
                        Task {
                            await model.startChildMode()
                        }
                    } label: {
                        Label("再玩 \(model.settings.selectedPlayMinutes) 分钟", systemImage: "play.fill")
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
                    if model.settings.prefersBiometrics {
                        Button {
                            Task {
                                if await model.verifyBiometrics() {
                                    completeVerification()
                                }
                            }
                        } label: {
                            Label("Face ID / Touch ID", systemImage: "faceid")
                                .frame(maxWidth: 280)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    SecureField("家长 PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .frame(maxWidth: 320)

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
        .presentationDetents([.medium])
    }

    private func completeVerification() {
        if action == .continueAfterBreak {
            isVerified = true
        } else {
            dismiss()
            onVerified()
        }
    }
}
