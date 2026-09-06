import SwiftUI

struct StartConfirmationContext: Identifiable {
    let id = UUID()
    var collectionName: String?
    var applicationCount: Int
    var playSeconds: Int
    var breakSeconds: Int
    var isTestModeEnabled: Bool

    var collectionSummary: String {
        guard let collectionName else {
            return "不使用 App 合集"
        }
        return "\(collectionName) · \(applicationCount) 个 App"
    }

    var emptyCollectionMessage: String? {
        guard applicationCount == 0 else { return nil }
        if collectionName == nil {
            return "当前没有选择 App 合集，本轮会按全部 App / 网页实际使用计时。"
        }
        return "当前合集还没有 App，本轮会按全部 App / 网页实际使用计时。"
    }
}

struct StartConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    var context: StartConfirmationContext
    var onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Label("确认开始", systemImage: "play.circle.fill")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.teal)
                    .lineLimit(1)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 16) {
                summaryRow(icon: "square.grid.2x2.fill", title: "允许 App", value: context.collectionSummary)
                summaryRow(icon: "timer", title: "玩耍时长", value: durationText(seconds: context.playSeconds))
                summaryRow(icon: "pause.circle.fill", title: "休息时长", value: durationText(seconds: context.breakSeconds))
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            if context.isTestModeEnabled {
                Label("测试模式已开启，这一轮会使用短时间额度。", systemImage: "testtube.2")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            if let emptyCollectionMessage = context.emptyCollectionMessage {
                Label(emptyCollectionMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 12)

            Button {
                dismiss()
                onConfirm()
            } label: {
                Label("确认开始", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.teal)
                .frame(width: 32)

            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func durationText(seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60) 分钟"
        }
        return "\(seconds) 秒"
    }
}
