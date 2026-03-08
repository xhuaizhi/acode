import Foundation
import AppKit
import CryptoKit

/// ACode 自建更新服务器检查器
@MainActor
final class UpdateChecker: ObservableObject {
    @Published var latestVersion: String?
    @Published var currentVersion: String
    @Published var downloadUrl: String?
    @Published var releaseNotes: String?
    @Published var isChecking = false
    @Published var hasUpdate = false
    @Published var isDownloading = false
    @Published var isDownloaded = false
    var localPath: URL?
    private var expectedSha256: String?

    private static let apiBase = "https://acode.anna.tf"

    init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// 检查更新
    func checkForUpdates() async {
        isChecking = true
        defer { isChecking = false }

        let urlString = "\(Self.apiBase)/api/v1/update/check?version=\(currentVersion)&platform=mac"
        guard let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let result = try JSONDecoder().decode(UpdateCheckResponse.self, from: data)

            hasUpdate = result.hasUpdate
            if result.hasUpdate {
                latestVersion = result.version
                releaseNotes = result.notes
                downloadUrl = result.downloadUrl
                expectedSha256 = result.sha256
            }
        } catch {
            // 静默失败，不打扰用户
        }
    }

    /// 后台下载更新包
    func downloadUpdate() async {
        guard let urlStr = downloadUrl, let url = URL(string: urlStr) else { return }
        isDownloading = true
        defer { isDownloading = false }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let version = latestVersion ?? "unknown"
            let ext = url.pathExtension.isEmpty ? "dmg" : url.pathExtension
            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ACode_v\(version).\(ext)")

            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            // SHA256 校验（如果服务器提供了 hash）
            if let expected = expectedSha256, !expected.isEmpty {
                let fileData = try Data(contentsOf: destURL)
                let digest = SHA256.hash(data: fileData)
                let actual = digest.map { String(format: "%02x", $0) }.joined()
                if actual.lowercased() != expected.lowercased() {
                    NSLog("[UpdateChecker] SHA256 校验失败: 期望=\(expected), 实际=\(actual)")
                    try? FileManager.default.removeItem(at: destURL)
                    return
                }
            }

            localPath = destURL
            isDownloaded = true
        } catch {
            NSLog("[UpdateChecker] 下载更新失败: \(error.localizedDescription)")
        }
    }

    /// 安装并重启（挂载 DMG，复制 .app，重启）
    func installAndRestart() {
        guard let path = localPath else { return }

        let version = latestVersion ?? ""

        // 写重启标记到 UserDefaults
        UserDefaults.standard.set(version, forKey: "lastUpdatedVersion")

        if path.pathExtension == "dmg" {
            // 安全转义路径（防止 shell 注入）
            let safePath = path.path.replacingOccurrences(of: "'", with: "'\\''")
            // 使用 sync 确保 cp 完成后再 detach；waitUntilExit 确保脚本执行完毕再退出
            let script = """
            hdiutil attach '\(safePath)' -nobrowse -quiet && \
            sleep 2 && \
            cp -Rf /Volumes/ACode*/ACode.app /Applications/ 2>/dev/null || \
            cp -Rf /Volumes/ACode*/*.app /Applications/ 2>/dev/null; \
            sync; \
            hdiutil detach /Volumes/ACode* -quiet 2>/dev/null; \
            open -n /Applications/ACode.app
            """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", script]
            let pipe = Pipe()
            process.standardError = pipe
            do {
                try process.run()
            } catch {
                NSLog("[UpdateChecker] installAndRestart 脚本启动失败: \(error.localizedDescription)")
                return
            }
            // 等待脚本完成后再退出，最多等 30 秒
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        } else {
            // ZIP 或其他格式: 直接打开让系统处理
            NSWorkspace.shared.open(path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - API Response Model

private struct UpdateCheckResponse: Codable {
    let hasUpdate: Bool
    let version: String?
    let build: String?
    let title: String?
    let notes: String?
    let downloadUrl: String?
    let fileSize: Int64?
    let sha256: String?
    let isForced: Bool?

    enum CodingKeys: String, CodingKey {
        case hasUpdate = "has_update"
        case version
        case build
        case title
        case notes
        case downloadUrl = "download_url"
        case fileSize = "file_size"
        case sha256
        case isForced = "is_forced"
    }
}
