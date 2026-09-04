import FamilyControls
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var parentAction: ParentAction?
    @State private var now = Date()

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
                ToolbarItem(placement: .topBarTrailing) {
                    if model.hasParentPIN, model.isAuthorized {
                        Toggle(isOn: biometricBinding) {
                            Label("Face ID", systemImage: "faceid")
                        }
                        .toggleStyle(.button)
                    }
                }
            }
        }
        .onReceive(ticker) { value in
            now = value
            model.markWaitingParentIfNeeded()
        }
        .sheet(item: $parentAction) { action in
            ParentGateView(action: action) {
                Task {
                    await perform(action)
                }
            }
            .environmentObject(model)
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
                parentAction = .start
            })
        case .playing:
            PlayingView(onParentControl: {
                parentAction = .end
            })
        case .break:
            BreakView(now: now, onParentControl: {
                parentAction = .end
            })
        case .waitingParent:
            WaitingParentView {
                parentAction = .continueAfterBreak
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

    private func perform(_ action: ParentAction) async {
        parentAction = nil
        switch action {
        case .start, .nextRound:
            await model.startChildMode()
        case .end:
            model.endChildMode()
        case .continueAfterBreak:
            break
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
                SecureField("再输入一次", text: $confirmPIN)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
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
        }
    }
}

private struct ReadyView: View {
    @EnvironmentObject private var model: AppModel
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
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
}

private struct PlayingView: View {
    @EnvironmentObject private var model: AppModel
    var onParentControl: () -> Void

    var body: some View {
        StatePanel(
            icon: "timer",
            title: "儿童模式进行中",
            subtitle: "本轮额度：\(model.session?.playDurationMinutes ?? AppConstants.defaultPlayMinutes) 分钟实际使用",
            detail: "时间用完后会自动休息 \(model.session?.breakDurationMinutes ?? AppConstants.defaultBreakMinutes) 分钟",
            buttonTitle: "家长控制",
            buttonIcon: "lock.fill",
            action: onParentControl
        )
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
