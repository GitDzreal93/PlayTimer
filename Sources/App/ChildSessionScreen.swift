import SwiftUI

struct ChildSessionScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var now: Date
    var onParentControl: () -> Void

    @State private var isBreathing = false
    @State private var isBlinking = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 700 || geometry.size.height < 560

            ZStack {
                if compact {
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.87, blue: 0.72), Color(red: 0.94, green: 0.70, blue: 0.60)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    catImage
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        if compact {
                            readout(compact: true)
                            Spacer(minLength: 6)
                            compactCatImage
                                .frame(maxWidth: .infinity)
                                .frame(height: max(170, min(geometry.size.height * 0.42, 300)))
                                .accessibilityHidden(true)
                        } else {
                            readout(compact: false)
                            Spacer(minLength: 200)
                        }

                        footer(compact: compact)
                    }
                    .padding(.horizontal, compact ? 20 : 36)
                    .padding(.vertical, compact ? 18 : 28)
                    .frame(maxWidth: 1220)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: model.phase)
        .task(id: model.phase) {
            guard model.phase == .playing, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { break }
                withAnimation(.easeInOut(duration: 0.12)) { isBlinking = true }
                try? await Task.sleep(nanoseconds: 160_000_000)
                withAnimation(.easeInOut(duration: 0.15)) { isBlinking = false }
            }
        }
    }

    private var catImage: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
            if model.phase == .playing {
                Image("BlueCatResting")
                    .resizable()
                    .scaledToFill()
                    .opacity(isBlinking && !reduceMotion ? 1 : 0)
            }
        }
        .scaleEffect(isBreathing && !reduceMotion ? 1.025 : 1)
        .id(imageName)
        .transition(.opacity)
    }

    private var compactCatImage: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFit()
            if model.phase == .playing {
                Image("BlueCatResting")
                    .resizable()
                    .scaledToFit()
                    .opacity(isBlinking && !reduceMotion ? 1 : 0)
            }
        }
        .scaleEffect(isBreathing && !reduceMotion ? 1.025 : 1)
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            Text("PlayTimer")
                .font(.title3.bold())
            Spacer()
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.70), in: Capsule())
        }
        .foregroundStyle(PlayTimerTheme.ink)
    }

    private func readout(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            Text(title)
                .font(.system(size: compact ? 26 : 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(largeText)
                .font(.system(size: compact ? 58 : 82, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .accessibilityLabel(accessibilityTimeLabel)
            Text(subtitle)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PlayTimerTheme.mutedInk)
        }
        .foregroundStyle(PlayTimerTheme.ink)
        .padding(.top, compact ? 4 : 18)
    }

    private func footer(compact: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                footerText(compact: compact)
                Spacer(minLength: 8)
                parentButton(compact: compact)
            }
            VStack(alignment: .leading, spacing: 14) {
                footerText(compact: compact)
                parentButton(compact: compact)
            }
        }
        .padding(compact ? 16 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(compact ? Color.white.opacity(0.68) : Color.white.opacity(0.22),
                    in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white.opacity(compact ? 0.5 : 0.20), lineWidth: 1))
        .padding(.bottom, compact ? 0 : 8)
    }

    private func footerText(compact: Bool) -> some View {
        Text(footerMessage)
            .font(.system(size: compact ? 17 : 20, weight: .bold, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(compact ? PlayTimerTheme.ink : .white)
            .shadow(color: compact ? .clear : .black.opacity(0.35), radius: 3, y: 1)
    }

    private func parentButton(compact: Bool) -> some View {
        Button(action: onParentControl) {
            Text(model.phase == .waitingParent ? "家长继续" : "家长控制")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(PlayTimerTheme.teal.opacity(compact ? 1 : 0.92),
                            in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    private var imageName: String {
        model.phase == .playing ? "BlueCatPlaying" : "BlueCatResting"
    }

    private var statusText: String {
        switch model.phase {
        case .playing: return "正在玩"
        case .break: return "休息中"
        case .waitingParent: return "等待家长"
        case .ready, .error: return "PlayTimer"
        }
    }

    private var title: String {
        switch model.phase {
        case .playing: return "开心玩一会儿"
        case .break: return "眼睛也要休息啦"
        case .waitingParent: return "休息结束啦"
        case .ready, .error: return "PlayTimer"
        }
    }

    private var largeText: String {
        switch model.phase {
        case .playing:
            let total = model.session?.playDurationSeconds ?? model.effectivePlaySeconds
            let elapsed = max(0, Int(now.timeIntervalSince(model.session?.startedAt ?? now)))
            return Self.clock(max(0, total - elapsed))
        case .break:
            guard let end = model.session?.breakEndAt else { return "--:--" }
            return Self.clock(max(0, Int(end.timeIntervalSince(now))))
        case .waitingParent:
            return "请找家长"
        case .ready, .error:
            return "--:--"
        }
    }

    private var subtitle: String {
        switch model.phase {
        case .playing: return "距离休息还有一段时间"
        case .break: return "喝口水，看看远处"
        case .waitingParent: return "家长验证后可以开始新一轮"
        case .ready, .error: return ""
        }
    }

    private var footerMessage: String {
        switch model.phase {
        case .playing:
            let seconds = model.session?.breakDurationSeconds ?? model.effectiveBreakSeconds
            return "游玩时间结束后，将休息 \(Self.durationText(seconds))。"
        case .break, .waitingParent:
            return "休息结束后请找家长"
        case .ready, .error:
            return ""
        }
    }

    private var accessibilityTimeLabel: String {
        model.phase == .waitingParent ? largeText : "剩余时间 \(largeText)"
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func durationText(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) 分钟" : "\(seconds) 秒"
    }
}
