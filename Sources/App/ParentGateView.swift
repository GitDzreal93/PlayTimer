import SwiftUI

enum ParentAction: String, Identifiable {
    case start, end, continueAfterBreak, nextRound, editAllowedApps

    var id: String { rawValue }
}

struct ParentGateView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var action: ParentAction
    var onVerified: () -> Void

    @State private var pin = ""
    @State private var didFail = false
    @State private var biometricFailure = false
    @State private var isVerified = false
    @State private var isBreathing = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if geometry.size.width >= 1000 {
                    HStack(spacing: 0) {
                        catArtwork
                            .frame(width: geometry.size.width * 2 / 3)
                        form
                            .frame(width: geometry.size.width / 3)
                    }
                    .frame(minHeight: geometry.size.height)
                } else {
                    VStack(spacing: 0) {
                        catArtwork
                            .frame(height: min(geometry.size.height * 0.32, 260))
                        form
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .background(PlayTimerTheme.surface)
        }
        .preferredColorScheme(.light)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private var catArtwork: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(red: 1, green: 0.87, blue: 0.73), Color(red: 0.94, green: 0.71, blue: 0.60)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image("BlueCatPeekaboo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.88,
                           height: geometry.size.height * 0.94,
                           alignment: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .scaleEffect(isBreathing && !reduceMotion ? 1.015 : 1)
                    .accessibilityLabel("蓝猫用前爪捂住眼睛")

                Text("轮到家长啦")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PlayTimerTheme.ink)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.64), in: Capsule())
                    .padding(26)
            }
            .clipped()
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(PlayTimerTheme.mutedInk)
                        .frame(width: 38, height: 38)
                        .background(PlayTimerTheme.canvas, in: Circle())
                }
                .accessibilityLabel("关闭")
            }

            Spacer(minLength: 32)

            Text("家长控制")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(PlayTimerTheme.teal)
                .padding(.bottom, 9)
            Text(isVerified ? "接下来怎么做？" : "家长验证")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PlayTimerTheme.ink)
                .padding(.bottom, 10)
            Text(isVerified ? "休息已经结束，可以开始新一轮或结束儿童模式。"
                 : "输入家长 PIN，才能结束或继续儿童模式。")
                .font(.body)
                .foregroundStyle(PlayTimerTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 26)

            if isVerified {
                verifiedActions
            } else {
                verificationControls
            }

            Spacer(minLength: 32)
            Text("孩子无法直接跳过验证")
                .font(.footnote)
                .foregroundStyle(PlayTimerTheme.mutedInk)
                .frame(maxWidth: .infinity)
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PlayTimerTheme.surface)
    }

    private var verificationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("家长 PIN")
                .font(.subheadline.weight(.bold))
            SecureField("输入 4–6 位 PIN", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.title3)
                .padding(15)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(PlayTimerTheme.softTeal, lineWidth: 2))
                .onChange(of: pin) { value in
                    pin = String(value.filter(\.isNumber).prefix(6))
                    didFail = false
                    biometricFailure = false
                }

            if didFail {
                Text("PIN 不正确，请重试。")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button {
                guard model.verifyPIN(pin) else {
                    didFail = true
                    return
                }
                completeVerification()
            } label: {
                Text("验证并继续")
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!(4...6).contains(pin.count))
            .padding(.top, 4)

            if model.settings.prefersBiometrics {
                Button {
                    Task {
                        if await model.verifyBiometrics() {
                            completeVerification()
                        } else {
                            biometricFailure = true
                        }
                    }
                } label: {
                    Text("使用 Face ID / Touch ID")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PlayTimerTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }

            if biometricFailure {
                Text("生物识别未完成，请使用家长 PIN。")
                    .font(.subheadline)
                    .foregroundStyle(PlayTimerTheme.mutedInk)
            }
        }
    }

    private var verifiedActions: some View {
        VStack(spacing: 12) {
            Button(action: onVerified) {
                Text("再玩 \(durationText(seconds: model.effectivePlaySeconds))")
            }
            .buttonStyle(PrimaryActionStyle())

            Button(role: .destructive) {
                model.endChildMode()
                dismiss()
            } label: {
                Text("结束儿童模式")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.bordered)
        }
    }

    private func completeVerification() {
        if action == .continueAfterBreak {
            isVerified = true
        } else {
            onVerified()
        }
    }

    private func durationText(seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) 分钟" : "\(seconds) 秒"
    }
}
