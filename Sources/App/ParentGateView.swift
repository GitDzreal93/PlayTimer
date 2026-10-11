import SwiftUI

enum ParentAction: String, Identifiable {
    case start, end, continueAfterBreak, nextRound, editAllowedApps, configureRecoveryQuestions

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
    @State private var isRecoveringPIN = false
    @State private var recoveryAnswersVerified = false
    @State private var deviceOwnerRecoveryVerified = false
    @State private var recoveryAnswer1 = ""
    @State private var recoveryAnswer2 = ""
    @State private var replacementPIN = ""
    @State private var replacementPINConfirmation = ""
    @State private var recoveryError: String?
    @State private var recoverySuccessMessage: String?
    @State private var recoveryQuestion = ""
    @State private var recoveryAnswer = ""
    @State private var recoveryQuestionMismatch = false

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
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PlayTimerTheme.ink)
                .padding(.bottom, 10)
            Text(description)
                .font(.body)
                .foregroundStyle(PlayTimerTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 26)

            if isVerified && action == .configureRecoveryQuestions {
                recoveryQuestionSetupForm
            } else if isVerified {
                verifiedActions
            } else if isRecoveringPIN {
                recoveryControls
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

    private var title: String {
        if isVerified && action == .configureRecoveryQuestions { return "设置 PIN 找回问题" }
        if isVerified { return "接下来怎么做？" }
        if isRecoveringPIN { return "找回 PIN" }
        return "家长验证"
    }

    private var description: String {
        if isVerified && action == .configureRecoveryQuestions {
            return "选择一道只有家长知道答案的问题。答案只保存在这台 iPad 的钥匙串中。"
        }
        if isVerified { return "休息已经结束，可以开始新一轮或结束儿童模式。" }
        if isRecoveringPIN && model.recoveryQuestionPrompts.isEmpty {
            return "这台 iPad 尚未设置找回问题。请先验证 iPad 设备所有者身份，然后在此设置新 PIN 和找回问题。"
        }
        if isRecoveringPIN {
            return model.recoveryQuestionPrompts.count == 1
                ? "回答设置 PIN 时选择的问题，验证通过后即可创建新 PIN。"
                : "回答设置 PIN 时设置的问题，验证通过后即可创建新 PIN。"
        }
        return "输入家长 PIN，才能结束或继续儿童模式。"
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
                    recoverySuccessMessage = nil
                }

            if let recoverySuccessMessage {
                Text(recoverySuccessMessage)
                    .font(.subheadline)
                    .foregroundStyle(PlayTimerTheme.teal)
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

            Button("忘记 PIN？") {
                isRecoveringPIN = true
                didFail = false
                recoveryError = nil
                deviceOwnerRecoveryVerified = false
                recoveryAnswersVerified = false
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PlayTimerTheme.teal)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var recoveryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.recoveryQuestionPrompts.isEmpty && deviceOwnerRecoveryVerified {
                legacyRecoverySetupForm
            } else if model.recoveryQuestionPrompts.isEmpty {
                Text("此 PIN 尚无找回问题。通过 Face ID、Touch ID 或 iPad 设备密码验证后，就能直接设置新 PIN 和找回问题。")
                    .font(.subheadline)
                    .foregroundStyle(PlayTimerTheme.mutedInk)

                Button("验证设备身份并重设") {
                    Task {
                        if await model.verifyDeviceOwnerForPINRecovery() {
                            deviceOwnerRecoveryVerified = true
                            recoveryError = nil
                        } else {
                            recoveryError = "设备身份验证未完成。请确认 iPad 已设置设备密码后重试。"
                        }
                    }
                }
                .buttonStyle(PrimaryActionStyle())
            } else if recoveryAnswersVerified {
                Text("设置新 PIN")
                    .font(.subheadline.weight(.bold))
                SecureField("输入新的 4–6 位 PIN", text: $replacementPIN)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: replacementPIN) { replacementPIN = String($0.filter(\.isNumber).prefix(6)) }
                SecureField("再次输入新 PIN", text: $replacementPINConfirmation)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: replacementPINConfirmation) { replacementPINConfirmation = String($0.filter(\.isNumber).prefix(6)) }

                Button("保存新 PIN") {
                    guard replacementPIN == replacementPINConfirmation else {
                        recoveryError = "两次输入的新 PIN 不一致。"
                        return
                    }
                    guard model.resetPINUsingRecoveryQuestions(replacementPIN) else { return }
                    finishPINRecovery()
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!(4...6).contains(replacementPIN.count) || !(4...6).contains(replacementPINConfirmation.count))
            } else {
                ForEach(Array(model.recoveryQuestionPrompts.enumerated()), id: \.offset) { index, prompt in
                    Text(prompt)
                        .font(.subheadline.weight(.semibold))
                    SecureField("答案 \(index + 1)", text: index == 0 ? $recoveryAnswer1 : $recoveryAnswer2)
                        .textFieldStyle(.roundedBorder)
                }

                Button("验证答案") {
                    switch model.verifyPINRecoveryAnswers([recoveryAnswer1, recoveryAnswer2]) {
                    case .verified:
                        recoveryAnswersVerified = true
                        recoveryError = nil
                    case .incorrect:
                        recoveryError = "答案不正确。连续答错 5 次后将暂停 5 分钟。"
                    case .cooldown(let seconds):
                        recoveryError = "尝试次数过多，请在 \(max(1, seconds / 60)) 分钟后重试。"
                    case .notConfigured:
                        recoveryError = "尚未设置找回问题。"
                    }
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(model.recoveryQuestionPrompts.count == 1
                    ? recoveryAnswer1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    : recoveryAnswer1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recoveryAnswer2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let recoveryError {
                Text(recoveryError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button("返回 PIN 验证") {
                isRecoveringPIN = false
                recoveryError = nil
                recoveryAnswersVerified = false
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PlayTimerTheme.teal)
            .frame(maxWidth: .infinity)
        }
    }

    private var legacyRecoverySetupForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置新 PIN 和找回问题")
                .font(.subheadline.weight(.bold))
            SecureField("输入新的 4–6 位 PIN", text: $replacementPIN)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: replacementPIN) { replacementPIN = String($0.filter(\.isNumber).prefix(6)) }
            SecureField("再次输入新 PIN", text: $replacementPINConfirmation)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: replacementPINConfirmation) { replacementPINConfirmation = String($0.filter(\.isNumber).prefix(6)) }

            RecoveryQuestionField(question: $recoveryQuestion, answer: $recoveryAnswer)

            if recoveryQuestionMismatch {
                Text("两次输入的新 PIN 不一致，请检查后重试。")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button("保存新 PIN 和找回问题") {
                recoveryQuestionMismatch = replacementPIN != replacementPINConfirmation
                guard !recoveryQuestionMismatch else { return }
                guard model.resetPINAndConfigureRecovery(replacementPIN, questionsAndAnswers: [
                    (question: recoveryQuestion, answer: recoveryAnswer)
                ]) else { return }
                finishPINRecovery()
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!legacyRecoveryCanSave)
        }
    }

    private var legacyRecoveryCanSave: Bool {
        (4...6).contains(replacementPIN.count) && (4...6).contains(replacementPINConfirmation.count) &&
            !recoveryQuestion.isEmpty && !recoveryAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func finishPINRecovery() {
        isRecoveringPIN = false
        recoveryAnswersVerified = false
        deviceOwnerRecoveryVerified = false
        recoveryAnswer1 = ""
        recoveryAnswer2 = ""
        replacementPIN = ""
        replacementPINConfirmation = ""
        recoveryQuestion = ""
        recoveryAnswer = ""
        pin = ""
        recoveryError = nil
        recoveryQuestionMismatch = false
        recoverySuccessMessage = "PIN 已重置，请使用新 PIN 验证。"
    }

    private var recoveryQuestionSetupForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecoveryQuestionField(question: $recoveryQuestion, answer: $recoveryAnswer)

            if recoveryQuestionMismatch {
                Text("请选择问题并填写答案。")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button("保存找回问题") {
                guard model.configurePINRecoveryQuestions([
                    (question: recoveryQuestion, answer: recoveryAnswer)
                ]) else { return }
                dismiss()
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!recoveryQuestionsCanSave)
        }
    }

    private var recoveryQuestionsCanSave: Bool {
        !recoveryQuestion.isEmpty && !recoveryAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        if action == .continueAfterBreak || action == .configureRecoveryQuestions {
            isVerified = true
        } else {
            onVerified()
        }
    }

    private func durationText(seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) 分钟" : "\(seconds) 秒"
    }
}
