import Foundation

/// GitHub Release 版本更新检查器
@MainActor
final class UpdateChecker: ObservableObject {
    @Published var latestVersion: String?
    @Published var currentVersion: String
    @Published var downloadUrl: String?
    @Published var releaseNotes: String?
    @Published var isChecking = false
    @Published var hasUpdate = false

    private let githubOwner: String
    private let githubRepo: String

    init(owner: String = "ACodeTeam", repo: String = "acode") {
        self.githubOwner = owner
        self.githubRepo = repo
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// 检查更新
    func checkForUpdates() async {
        isChecking = true
        defer { isChecking = false }

        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            releaseNotes = release.body
            downloadUrl = release.htmlUrl

            // macOS 资产优先
            if let macAsset = release.assets.first(where: {
                $0.name.lowercased().contains("macos") || $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip")
            }) {
                downloadUrl = macAsset.browserDownloadUrl
            }

            hasUpdate = isNewerVersion(latestVersion ?? "", than: currentVersion)
        } catch {
            // 静默失败，不打扰用户
        }
    }

    /// 语义化版本比较
    private func isNewerVersion(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}

// MARK: - GitHub API Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}
