import XCTest

final class ACodeTests: XCTestCase {

    func testProviderFormDataDefaults() {
        let form = ProviderFormData()
        XCTAssertEqual(form.tool, "claude_code")
        XCTAssertTrue(form.apiKey.isEmpty)
        XCTAssertEqual(form.extraEnv, "{}")
    }

    func testDefaultModels() {
        XCTAssertFalse(DefaultModels.claude.isEmpty)
        XCTAssertFalse(DefaultModels.openai.isEmpty)
        XCTAssertFalse(DefaultModels.gemini.isEmpty)
        XCTAssertEqual(DefaultModels.defaultModel(for: "claude_code"), "claude-sonnet-4-20250514")
        XCTAssertEqual(DefaultModels.defaultModel(for: "openai"), "o4-mini")
        XCTAssertEqual(DefaultModels.defaultModel(for: "gemini"), "gemini-2.5-pro")
    }

    func testProviderIconInference() {
        let claude = ProviderIconInference.infer(name: "Claude Official")
        XCTAssertNotNil(claude)
        XCTAssertEqual(claude?.name, "anthropic")

        let openai = ProviderIconInference.infer(name: "OpenAI")
        XCTAssertNotNil(openai)
        XCTAssertEqual(openai?.name, "openai")

        let unknown = ProviderIconInference.infer(name: "random provider")
        XCTAssertNil(unknown)
    }

    func testProviderMaskedApiKey() {
        let provider = Provider(
            id: 1, name: "Test", tool: "claude_code",
            apiKey: "sk-ant-api03-abcdef1234567890",
            apiBase: "", model: "claude-sonnet-4", isActive: true,
            sortOrder: 0, presetId: nil, extraEnv: "{}",
            icon: nil, iconColor: nil, notes: nil, category: nil,
            createdAt: 0, updatedAt: 0
        )
        let masked = provider.maskedApiKey
        XCTAssertTrue(masked.hasPrefix("sk-a"))
        XCTAssertTrue(masked.hasSuffix("7890"))
        XCTAssertTrue(masked.contains("•"))
    }
}
