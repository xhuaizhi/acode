import SwiftUI

/// 底部更新通知 Toast
struct UpdateToastView: View {
    let version: String
    let notes: String?
    var isDownloaded: Bool = false
    var isDownloading: Bool = false
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    private var iconName: String {
        if isDownloaded { return "checkmark.circle.fill" }
        if isDownloading { return "arrow.down.circle" }
        return "arrow.down.circle.fill"
    }

    private var titleText: String {
        if isDownloaded { return "v\(version) 更新已就绪" }
        if isDownloading { return "正在下载 v\(version)..." }
        return "新版本 v\(version) 可用"
    }

    private var buttonText: String {
        isDownloaded ? "重启更新" : "查看更新"
    }

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            if isDownloading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }

            // 文本
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                if let notes = notes, !notes.isEmpty {
                    Text(notes.prefix(80) + (notes.count > 80 ? "..." : ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 操作按钮（下载中时禁用）
            Button(buttonText) {
                onUpdate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isDownloading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }
}
