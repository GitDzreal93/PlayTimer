import SwiftUI

struct ParentReadyScreen: View {
    @EnvironmentObject private var model: AppModel
    var onStart: () -> Void
    var onEditAllowedApps: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    introduction
                    allowedAppsCard(compact: geometry.size.width < 600)

                    if model.settings.isTestModeEnabled {
                        Label("测试模式已开启：可用短时长验证流程", systemImage: "testtube.2")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PlayTimerTheme.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PlayTimerTheme.softTeal, in: RoundedRectangle(cornerRadius: 14))
                    }

                    durationSection(
                        title: "游玩时长",
                        options: model.settings.isTestModeEnabled ? AppConstants.testPlaySecondOptions : AppConstants.playMinuteOptions,
                        selected: model.settings.isTestModeEnabled ? model.settings.selectedTestPlaySeconds : model.settings.selectedPlayMinutes,
                        isTest: model.settings.isTestModeEnabled
                    ) { value in
                        if model.settings.isTestModeEnabled {
                            model.saveSettings(testPlaySeconds: value)
                        } else {
                            model.saveSettings(playMinutes: value)
                        }
                    }

                    durationSection(
                        title: "休息时长",
                        options: model.settings.isTestModeEnabled ? AppConstants.testBreakSecondOptions : AppConstants.breakMinuteOptions,
                        selected: model.settings.isTestModeEnabled ? model.settings.selectedTestBreakSeconds : model.settings.selectedBreakMinutes,
                        isTest: model.settings.isTestModeEnabled
                    ) { value in
                        if model.settings.isTestModeEnabled {
                            model.saveSettings(testBreakSeconds: value)
                        } else {
                            model.saveSettings(breakMinutes: value)
                        }
                    }

                    VStack(spacing: 12) {
                        Toggle("使用设备生物识别", isOn: Binding(
                            get: { model.settings.prefersBiometrics },
                            set: { model.saveSettings(prefersBiometrics: $0) }
                        ))
                        Toggle("测试模式", isOn: Binding(
                            get: { model.settings.isTestModeEnabled },
                            set: { model.saveSettings(isTestModeEnabled: $0) }
                        ))
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(PlayTimerTheme.teal)
                    .padding(18)
                    .background(PlayTimerTheme.surface, in: RoundedRectangle(cornerRadius: 18))

                    Text("开始前会再次确认本轮的 App 与时间设置。")
                        .font(.subheadline)
                        .foregroundStyle(PlayTimerTheme.mutedInk)

                }
                .padding(.horizontal, geometry.size.width < 600 ? 20 : 36)
                .padding(.vertical, 28)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: onStart) {
                    Label("开始儿童模式", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(model.isBusy)
                .padding(.horizontal, geometry.size.width < 600 ? 20 : 36)
                .padding(.vertical, 12)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
                .background(PlayTimerTheme.canvas.opacity(0.97))
            }
            .background(PlayTimerTheme.canvas)
        }
        .foregroundStyle(PlayTimerTheme.ink)
    }

    private var header: some View {
        HStack {
            Text("PlayTimer")
                .font(.title2.bold())
            Spacer()
            Text("家长设置")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PlayTimerTheme.teal)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(PlayTimerTheme.softTeal, in: Capsule())
        }
    }

    private var introduction: some View {
        HStack(spacing: 18) {
            Image("BlueCatPlaying")
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("安排好玩耍时间")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.8)
                Text("设置一次，就能安心交给孩子。")
                    .font(.body)
                    .foregroundStyle(PlayTimerTheme.mutedInk)
            }
        }
    }

    @ViewBuilder
    private func allowedAppsCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("允许使用的 App")
                .font(.title3.bold())

            if compact {
                VStack(alignment: .leading, spacing: 14) {
                    appSummary
                    editAppsButton
                }
                .cardSurface()
            } else {
                HStack(spacing: 16) {
                    appSummary
                    Spacer(minLength: 8)
                    editAppsButton
                }
                .cardSurface()
            }
        }
    }

    private var appSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.selectedAllowedAppCollection.map { "\($0.name) · \($0.applicationCount) 个 App" } ?? "不使用 App 合集")
                .font(.headline)
            Text(model.allowedAppCount == 0
                 ? "开始后按全部 App / 网页实际使用计时"
                 : "游玩期间只允许并计时这些 App")
                .font(.subheadline)
                .foregroundStyle(PlayTimerTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var editAppsButton: some View {
        Button(action: onEditAllowedApps) {
            Label("修改", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(PlayTimerTheme.softTeal, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(PlayTimerTheme.teal)
    }

    private func durationSection(
        title: String,
        options: [Int],
        selected: Int,
        isTest: Bool,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                ForEach(options, id: \.self) { value in
                    let isSelected = selected == value
                    Button {
                        onSelect(value)
                    } label: {
                        Text(isTest ? (value == 60 ? "1 分钟" : "\(value) 秒") : "\(value) 分钟")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(isSelected ? PlayTimerTheme.softTeal : PlayTimerTheme.surface,
                                        in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13)
                                .stroke(isSelected ? PlayTimerTheme.teal : PlayTimerTheme.border, lineWidth: isSelected ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

private extension View {
    func cardSurface() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlayTimerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(PlayTimerTheme.border, lineWidth: 1))
    }
}
