import AudioToolbox
import FamilyControls
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var now = Date()
    @State private var activeSheet: ActiveSheet?
    @State private var parentAction: ParentAction?
    @State private var lastAnnouncedPhase: SessionPhase?
    @Environment(\.scenePhase) private var scenePhase

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            PlayTimerTheme.canvas.ignoresSafeArea()

            if !model.hasParentPIN {
                PINSetupView()
                    .padding(24)
                    .frame(maxWidth: 680)
            } else if !model.isAuthorized {
                AuthorizationView()
                    .padding(24)
                    .frame(maxWidth: 680)
            } else {
                sessionContent
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            lastAnnouncedPhase = model.phase
            #if DEBUG
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("-PlayTimerPreviewGate") {
                parentAction = .end
            }
            if ProcessInfo.processInfo.arguments.contains("-MarketingCaptureParentGate") {
                parentAction = .continueAfterBreak
            }
            if ProcessInfo.processInfo.arguments.contains("-MarketingCaptureCollection") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    activeSheet = .appCollections
                }
            }
            #endif
            #endif
        }
        .onReceive(ticker) { value in
            now = value
            let phaseBeforeRefresh = model.session?.phase ?? model.phase
            model.syncSessionFromStoreAndMarkWaitingParentIfNeeded()
            announcePhaseChange(from: phaseBeforeRefresh, to: model.phase)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        .fullScreenCover(item: $parentAction) { action in
            ParentGateView(action: action) {
                perform(action)
            }
            .environmentObject(model)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .appCollections:
                AllowedAppCollectionsView()
                    .environmentObject(model)
            case .startConfirmation(let context):
                StartConfirmationView(context: context) {
                    activeSheet = nil
                    Task {
                        await model.startChildMode()
                    }
                }
            }
        }
        .alert("提示", isPresented: alertBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private func announcePhaseChange(from oldPhase: SessionPhase, to newPhase: SessionPhase) {
        guard newPhase != oldPhase, newPhase != lastAnnouncedPhase else { return }
        lastAnnouncedPhase = newPhase

        switch newPhase {
        case .break:
            SessionFeedback.playBreakStarted()
        case .waitingParent:
            SessionFeedback.playBreakFinished()
        case .ready, .playing, .error:
            break
        }
    }

    @ViewBuilder
    private var sessionContent: some View {
        switch model.phase {
        case .ready:
            ParentReadyScreen(onStart: {
                parentAction = .start
            }, onEditAllowedApps: {
                parentAction = .editAllowedApps
            }, onSetupRecoveryQuestions: {
                parentAction = .configureRecoveryQuestions
            })
        case .playing:
            ChildSessionScreen(now: now, onParentControl: {
                parentAction = .end
            })
        case .break:
            ChildSessionScreen(now: now, onParentControl: {
                parentAction = .end
            })
        case .waitingParent:
            ChildSessionScreen(now: now, onParentControl: {
                parentAction = .continueAfterBreak
            })
        case .error:
            ErrorStateView {
                Task {
                    await model.refresh()
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )
    }

    private func perform(_ action: ParentAction) {
        switch action {
        case .start, .nextRound, .continueAfterBreak:
            let context = makeStartConfirmationContext()
            parentAction = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                activeSheet = .startConfirmation(context)
            }
        case .end:
            model.endChildMode()
            parentAction = nil
        case .editAllowedApps:
            parentAction = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                activeSheet = .appCollections
            }
        case .configureRecoveryQuestions:
            parentAction = nil
        }
    }

    private func makeStartConfirmationContext() -> StartConfirmationContext {
        StartConfirmationContext(
            collectionName: model.selectedAllowedAppCollection?.name,
            applicationCount: model.allowedAppCount,
            playSeconds: model.effectivePlaySeconds,
            breakSeconds: model.effectiveBreakSeconds,
            isTestModeEnabled: model.settings.isTestModeEnabled
        )
    }
}

private enum ActiveSheet: Identifiable {
    case appCollections
    case startConfirmation(StartConfirmationContext)

    var id: String {
        switch self {
        case .appCollections:
            return "app-collections"
        case .startConfirmation(let context):
            return "start-confirmation-\(context.id.uuidString)"
        }
    }
}

private struct AuthorizationView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image("BlueCatPlaying")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityHidden(true)

                Text("再完成一步")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PlayTimerTheme.teal)
                Text("授权屏幕时间")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PlayTimerTheme.ink)
                Text("PlayTimer 需要这台 iPad 的屏幕时间权限，才能在游玩时间结束时暂停受限 App。")
                    .font(.title3)
                    .foregroundStyle(PlayTimerTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await model.requestScreenTimeAuthorization() }
                } label: {
                    Label(model.isBusy ? "正在请求授权…" : "授权屏幕时间", systemImage: "checkmark.shield.fill")
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(model.isBusy)
                .padding(.top, 8)

                Text("请按系统提示完成授权。")
                    .font(.subheadline)
                    .foregroundStyle(PlayTimerTheme.mutedInk)
            }
            .padding(32)
            .frame(maxWidth: 560, alignment: .leading)
            .background(PlayTimerTheme.surface, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(PlayTimerTheme.border))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 560)
        }
    }
}

private struct PINSetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var mismatch = false
    @State private var recoveryQuestion = ""
    @State private var recoveryAnswer = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image("BlueCatPeekaboo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityHidden(true)

                Text("家长设置")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PlayTimerTheme.teal)
                Text("创建家长 PIN")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PlayTimerTheme.ink)
                Text("设置 4–6 位数字。结束或继续儿童模式时，需要家长验证。")
                    .font(.title3)
                    .foregroundStyle(PlayTimerTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    SecureField("输入 4–6 位数字", text: $pin)
                        .onChange(of: pin) { value in pin = sanitizedPIN(value) }
                    SecureField("再次输入 PIN", text: $confirmPIN)
                        .onChange(of: confirmPIN) { value in confirmPIN = sanitizedPIN(value) }
                }
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.title3)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(PlayTimerTheme.border))

                Text("设置 PIN 找回问题")
                    .font(.headline)
                    .foregroundStyle(PlayTimerTheme.ink)
                Text("忘记 PIN 时，回答这道问题即可重设。请选择孩子不容易猜到、且自己能记住的问题。")
                    .font(.subheadline)
                    .foregroundStyle(PlayTimerTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                RecoveryQuestionField(question: $recoveryQuestion, answer: $recoveryAnswer)

                if mismatch {
                    Text("两次输入不一致，请重试。")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Button {
                    mismatch = pin != confirmPIN
                    guard !mismatch else { return }
                    _ = model.createPIN(pin, questionsAndAnswers: [(question: recoveryQuestion, answer: recoveryAnswer)])
                } label: {
                    Label("保存 PIN", systemImage: "key.fill")
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!canAttemptSave)
                .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: 560, alignment: .leading)
            .background(PlayTimerTheme.surface, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(PlayTimerTheme.border))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 620)
        }
    }

    private var canAttemptSave: Bool {
        (4...6).contains(pin.count) && (4...6).contains(confirmPIN.count) &&
            !recoveryQuestion.isEmpty && !recoveryAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum PINRecoveryQuestion: String, CaseIterable, Identifiable {
    case familyCode = "你们家的家庭暗号是什么？"
    case parentNickname = "家长小时候的昵称是什么？"
    case firstPet = "家长小时候第一只宠物叫什么？"
    case favoriteTeacher = "家长最喜欢的老师姓什么？"
    case firstTrip = "家长第一次独自旅行去了哪里？"
    case favoriteBook = "家长小时候最喜欢的一本书叫什么？"

    var id: String { rawValue }
}

struct RecoveryQuestionField: View {
    @Binding var question: String
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("找回问题")
                .font(.subheadline.weight(.semibold))
            Picker("选择一个问题", selection: $question) {
                Text("请选择问题").tag("")
                ForEach(PINRecoveryQuestion.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(PlayTimerTheme.teal)
            SecureField("答案", text: $answer)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct ReadyView: View {
    @EnvironmentObject private var model: AppModel
    var onStart: () -> Void
    var onEditAllowedApps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("允许使用的 App")
                    .font(.title.bold())

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(allowedAppsTitle)
                            .font(.title3.bold())
                        Text(allowedAppsSubtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onEditAllowedApps) {
                        Label("修改", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if model.settings.isTestModeEnabled {
                Label("测试模式：可用 30 秒或 1 分钟快速验证流程", systemImage: "testtube.2")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            Text("给孩子玩多久？")
                .font(.largeTitle.bold())

            if model.settings.isTestModeEnabled {
                DurationSegmentedPicker(
                    options: AppConstants.testPlaySecondOptions,
                    selection: Binding(
                        get: { model.settings.selectedTestPlaySeconds },
                        set: { model.saveSettings(testPlaySeconds: $0) }
                    ),
                    labelProvider: testDurationLabel
                )
            } else {
                DurationSegmentedPicker(
                    options: AppConstants.playMinuteOptions,
                    selection: Binding(
                        get: { model.settings.selectedPlayMinutes },
                        set: { model.saveSettings(playMinutes: $0) }
                    )
                )
            }

            Text("休息多久？")
                .font(.title.bold())

            if model.settings.isTestModeEnabled {
                DurationSegmentedPicker(
                    options: AppConstants.testBreakSecondOptions,
                    selection: Binding(
                        get: { model.settings.selectedTestBreakSeconds },
                        set: { model.saveSettings(testBreakSeconds: $0) }
                    ),
                    labelProvider: testDurationLabel
                )
            } else {
                DurationSegmentedPicker(
                    options: AppConstants.breakMinuteOptions,
                    selection: Binding(
                        get: { model.settings.selectedBreakMinutes },
                        set: { model.saveSettings(breakMinutes: $0) }
                    )
                )
            }

            Button(action: onStart) {
                Label("开始儿童模式", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isBusy)
        }
    }

    private var allowedAppsTitle: String {
        guard let collection = model.selectedAllowedAppCollection else {
            return "不使用 App 合集"
        }
        return "\(collection.name) · \(collection.applicationCount) 个 App"
    }

    private var allowedAppsSubtitle: String {
        if model.allowedAppCount == 0 {
            return "开始后按全部 App / 网页实际使用计时"
        }
        return "开始后只允许这些 App，并只统计这些 App"
    }

    private func testDurationLabel(_ seconds: Int) -> String {
        seconds == 60 ? "1 分钟" : "\(seconds) 秒"
    }
}

private struct PlayingView: View {
    @EnvironmentObject private var model: AppModel
    var now: Date
    var onParentControl: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "timer.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.teal)

            VStack(spacing: 10) {
                Text("儿童模式进行中")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(remainingText)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)

                Text("预计剩余时间")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: progress)
                    .tint(.teal)

                Label("通知中心也会提示开始、休息和结束", systemImage: "bell.badge.fill")
                    .font(.headline)
                    .foregroundStyle(.teal)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(detailText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button(action: onParentControl) {
                Label("家长控制", systemImage: "lock.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var remainingText: String {
        let remaining = max(0, totalSeconds - elapsedSeconds)
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(elapsedSeconds) / Double(totalSeconds)))
    }

    private var elapsedSeconds: Int {
        guard let startedAt = model.session?.startedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(startedAt)))
    }

    private var totalSeconds: Int {
        model.session?.playDurationSeconds ?? AppConstants.defaultPlayMinutes * 60
    }

    private var detailText: String {
        let breakText = durationText(seconds: model.session?.breakDurationSeconds ?? AppConstants.defaultBreakMinutes * 60)
        let count = model.session?.allowedApplicationCount ?? 0
        let collectionName = model.session?.allowedCollectionName
        if count == 0 {
            if let collectionName {
                return "\(collectionName) 里还没有 App，当前按全部 App / 网页统计。时间到后会进入 \(breakText)休息。"
            }
            return "当前按全部 App / 网页统计。时间到后会进入 \(breakText)休息。"
        }
        if let collectionName {
            return "当前允许 \(collectionName) 中的 \(count) 个 App。时间到后会进入 \(breakText)休息。"
        }
        return "当前只允许 \(count) 个 App。时间到后会进入 \(breakText)休息。"
    }

    private func durationText(seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60) 分钟"
        }
        return "\(seconds) 秒"
    }
}

private struct BreakView: View {
    @EnvironmentObject private var model: AppModel
    var now: Date
    var onParentControl: () -> Void

    var body: some View {
        RestStateLayout(
            icon: "pause.circle.fill",
            iconColor: .yellow,
            title: "休息时间到了",
            headline: remainingText,
            detailLines: [
                "本轮 \(durationText(seconds: model.session?.playDurationSeconds ?? model.effectivePlaySeconds)) 已用完",
                breakEndText,
                "可以放下 iPad，喝水、活动一下。"
            ],
            buttonTitle: "家长控制",
            buttonIcon: "lock.fill",
            action: onParentControl
        )
    }

    private var remainingText: String {
        guard let end = model.session?.breakEndAt else { return "--:--" }
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var breakEndText: String {
        guard let end = model.session?.breakEndAt else { return "休息到 --:--" }
        return "休息到 \(end.formatted(date: .omitted, time: .shortened))"
    }

    private func durationText(seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60) 分钟"
        }
        return "\(seconds) 秒"
    }
}

private struct WaitingParentView: View {
    var onContinue: () -> Void

    var body: some View {
        RestStateLayout(
            icon: "checkmark.circle.fill",
            iconColor: .mint,
            title: "休息完成",
            headline: "请找爸爸妈妈",
            detailLines: [
                "家长验证后可以开始新一轮",
                "也可以结束儿童模式"
            ],
            buttonTitle: "家长继续",
            buttonIcon: "lock.fill",
            action: onContinue
        )
    }
}

private struct ErrorStateView: View {
    var onRetry: () -> Void

    var body: some View {
        StatePanel(
            icon: "exclamationmark.triangle.fill",
            title: "需要检查权限",
            subtitle: "屏幕时间权限已关闭或状态异常",
            detail: "重新授权后才能继续自动暂停 App 使用。",
            buttonTitle: "刷新",
            buttonIcon: "arrow.clockwise",
            action: onRetry
        )
    }
}

private struct RestStateLayout: View {
    var icon: String
    var iconColor: Color
    var title: String
    var headline: String
    var detailLines: [String]
    var buttonTitle: String
    var buttonIcon: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: icon)
                .font(.system(size: 82))
                .foregroundStyle(iconColor)
                .shadow(color: iconColor.opacity(0.35), radius: 18, y: 8)

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(headline)
                    .font(.system(size: 86, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .accessibilityLabel("剩余时间 \(headline)")

                VStack(spacing: 8) {
                    ForEach(detailLines, id: \.self) { line in
                        Text(line)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.84))
                            .multilineTextAlignment(.center)
                    }
                }
            }

            Button(action: action) {
                Label(buttonTitle, systemImage: buttonIcon)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.white)
            .foregroundStyle(Color(red: 0.06, green: 0.16, blue: 0.18))
        }
        .frame(maxWidth: 720)
        .padding(.vertical, 36)
    }
}

private struct StatePanel: View {
    var icon: String
    var title: String
    var subtitle: String
    var detail: String
    var buttonTitle: String
    var buttonIcon: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(.teal)

            VStack(spacing: 10) {
                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: action) {
                Label(buttonTitle, systemImage: buttonIcon)
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

@MainActor
private enum SessionFeedback {
    static func playBreakStarted() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1005)
    }

    static func playBreakFinished() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1025)
    }
}

private struct DurationSegmentedPicker: View {
    var options: [Int]
    @Binding var selection: Int
    var labelProvider: (Int) -> String = { "\($0) 分钟" }

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.self) { value in
                Text(labelProvider(value)).tag(value)
            }
        }
        .pickerStyle(.segmented)
    }
}

private func sanitizedPIN(_ value: String) -> String {
    String(value.filter(\.isNumber).prefix(6))
}
