import FamilyControls
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var now = Date()
    @State private var activeSheet: ActiveSheet?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.98, blue: 0.97), Color(red: 0.98, green: 0.96, blue: 0.91)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Group {
                    if !model.hasParentPIN {
                        PINSetupView()
                    } else if !model.isAuthorized {
                        AuthorizationView()
                    } else {
                        sessionContent
                    }
                }
                .padding(32)
                .frame(maxWidth: 720)
            }
            .navigationTitle("PlayTimer")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.hasParentPIN, model.isAuthorized {
                        Toggle(isOn: biometricBinding) {
                            Label("Face ID", systemImage: "faceid")
                        }
                        .toggleStyle(.button)

                        Button {
                            model.saveSettings(isTestModeEnabled: !model.settings.isTestModeEnabled)
                        } label: {
                            Label(
                                model.settings.isTestModeEnabled ? "关闭测试模式" : "测试模式",
                                systemImage: "testtube.2"
                            )
                        }
                        .tint(model.settings.isTestModeEnabled ? .orange : .accentColor)
                    }
                }
            }
        }
        .onReceive(ticker) { value in
            now = value
            model.markWaitingParentIfNeeded()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .parentGate(let action):
                ParentGateView(action: action) {
                    perform(action)
                }
                .environmentObject(model)
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

    @ViewBuilder
    private var sessionContent: some View {
        switch model.phase {
        case .ready:
            ReadyView(onStart: {
                activeSheet = .parentGate(.start)
            }, onEditAllowedApps: {
                activeSheet = .parentGate(.editAllowedApps)
            })
        case .playing:
            PlayingView(now: now, onParentControl: {
                activeSheet = .parentGate(.end)
            })
        case .break:
            BreakView(now: now, onParentControl: {
                activeSheet = .parentGate(.end)
            })
        case .waitingParent:
            WaitingParentView {
                activeSheet = .parentGate(.continueAfterBreak)
            }
        case .error:
            ErrorStateView {
                Task {
                    await model.refresh()
                }
            }
        }
    }

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { model.settings.prefersBiometrics },
            set: { model.saveSettings(prefersBiometrics: $0) }
        )
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
            activeSheet = .startConfirmation(makeStartConfirmationContext())
        case .end:
            model.endChildMode()
            activeSheet = nil
        case .editAllowedApps:
            activeSheet = .appCollections
        }
    }

    private func makeStartConfirmationContext() -> StartConfirmationContext {
        StartConfirmationContext(
            collectionName: model.selectedAllowedAppCollection?.name,
            applicationCount: model.allowedAppCount,
            playMinutes: model.effectivePlayMinutes,
            breakMinutes: model.settings.selectedBreakMinutes,
            isTestModeEnabled: model.settings.isTestModeEnabled
        )
    }
}

private enum ActiveSheet: Identifiable {
    case parentGate(ParentAction)
    case appCollections
    case startConfirmation(StartConfirmationContext)

    var id: String {
        switch self {
        case .parentGate(let action):
            return "parent-\(action.id)"
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
        VStack(spacing: 28) {
            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.teal)

            VStack(spacing: 10) {
                Text("授权屏幕时间")
                    .font(.largeTitle.bold())
                Text("PlayTimer 需要本机 Screen Time 权限，才能在额度用完后自动暂停可限制的 App 使用。")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await model.requestScreenTimeAuthorization()
                }
            } label: {
                Label(model.isBusy ? "授权中" : "授权", systemImage: "checkmark.shield.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isBusy)
        }
    }
}

private struct PINSetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var mismatch = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.teal)

            Text("创建家长 PIN")
                .font(.largeTitle.bold())

            VStack(spacing: 12) {
                SecureField("4-6 位数字", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: pin) { value in
                        pin = sanitizedPIN(value)
                    }
                SecureField("再输入一次", text: $confirmPIN)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: confirmPIN) { value in
                        confirmPIN = sanitizedPIN(value)
                    }
            }
            .textFieldStyle(.roundedBorder)
            .font(.title3)
            .frame(maxWidth: 360)

            if mismatch {
                Text("两次输入不一致。")
                    .foregroundStyle(.red)
            }

            Button {
                mismatch = pin != confirmPIN
                guard !mismatch else { return }
                _ = model.createPIN(pin)
            } label: {
                Label("保存 PIN", systemImage: "key.fill")
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canAttemptSave)
        }
    }

    private var canAttemptSave: Bool {
        (4...6).contains(pin.count) && (4...6).contains(confirmPIN.count)
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
                Label("测试模式：本轮会按 1 分钟计时", systemImage: "testtube.2")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            Text("给孩子玩多久？")
                .font(.largeTitle.bold())

            DurationSegmentedPicker(
                options: AppConstants.playMinuteOptions,
                selection: Binding(
                    get: { model.settings.selectedPlayMinutes },
                    set: { model.saveSettings(playMinutes: $0) }
                )
            )

            Text("休息多久？")
                .font(.title.bold())

            DurationSegmentedPicker(
                options: AppConstants.breakMinuteOptions,
                selection: Binding(
                    get: { model.settings.selectedBreakMinutes },
                    set: { model.saveSettings(breakMinutes: $0) }
                )
            )

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
        (model.session?.playDurationMinutes ?? AppConstants.defaultPlayMinutes) * 60
    }

    private var detailText: String {
        let breakMinutes = model.session?.breakDurationMinutes ?? AppConstants.defaultBreakMinutes
        let count = model.session?.allowedApplicationCount ?? 0
        let collectionName = model.session?.allowedCollectionName
        if count == 0 {
            if let collectionName {
                return "\(collectionName) 里还没有 App，当前按全部 App / 网页统计。时间到后会进入 \(breakMinutes) 分钟休息。"
            }
            return "当前按全部 App / 网页统计。时间到后会进入 \(breakMinutes) 分钟休息。"
        }
        if let collectionName {
            return "当前允许 \(collectionName) 中的 \(count) 个 App。时间到后会进入 \(breakMinutes) 分钟休息。"
        }
        return "当前只允许 \(count) 个 App。时间到后会进入 \(breakMinutes) 分钟休息。"
    }
}

private struct BreakView: View {
    @EnvironmentObject private var model: AppModel
    var now: Date
    var onParentControl: () -> Void

    var body: some View {
        StatePanel(
            icon: "pause.circle.fill",
            title: "休息一下",
            subtitle: remainingText,
            detail: "时间到后请把 iPad 交给爸爸妈妈",
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
}

private struct WaitingParentView: View {
    var onContinue: () -> Void

    var body: some View {
        StatePanel(
            icon: "checkmark.circle.fill",
            title: "休息完成",
            subtitle: "请把 iPad 交给爸爸妈妈",
            detail: "",
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

private struct DurationSegmentedPicker: View {
    var options: [Int]
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.self) { minutes in
                Text("\(minutes) 分钟").tag(minutes)
            }
        }
        .pickerStyle(.segmented)
    }
}

private func sanitizedPIN(_ value: String) -> String {
    String(value.filter(\.isNumber).prefix(6))
}
