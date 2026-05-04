import Foundation
import XCTest
@testable import Overwhisper

final class OpenAIEngineTests: XCTestCase {
    func testMultipartBodyIncludesSelectedLanguage() throws {
        let body = OpenAIEngine.makeMultipartBody(
            audioData: Data([0x01, 0x02, 0x03]),
            boundary: "boundary",
            language: "es",
            customVocabulary: ""
        )

        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"language\"\r\n\r\nes\r\n"))
    }

    func testMultipartBodyOmitsLanguageWhenAutoDetecting() throws {
        let body = OpenAIEngine.makeMultipartBody(
            audioData: Data([0x01, 0x02, 0x03]),
            boundary: "boundary",
            language: nil,
            customVocabulary: ""
        )

        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertFalse(text.contains("name=\"language\""))
    }

    func testMultipartBodyStillIncludesPromptWhenLanguageIsOmitted() throws {
        let body = OpenAIEngine.makeMultipartBody(
            audioData: Data([0x01, 0x02, 0x03]),
            boundary: "boundary",
            language: nil,
            customVocabulary: "Overwhisper, WhisperKit"
        )

        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertFalse(text.contains("name=\"language\""))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"prompt\"\r\n\r\nOverwhisper, WhisperKit\r\n"))
    }

    func testLanguageHintIsDisabledForTranslationRequests() {
        XCTAssertNil(OpenAIEngine.resolvedRequestLanguage("ko", translateToEnglish: true))
    }

    func testLanguageHintTrimsConcreteLanguageCodes() {
        XCTAssertEqual(OpenAIEngine.resolvedRequestLanguage(" es\n", translateToEnglish: false), "es")
    }
}
