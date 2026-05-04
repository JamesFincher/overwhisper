import XCTest
@testable import Overwhisper

final class HotkeyRegistrationPlanTests: XCTestCase {
    func testRegistersBothConfiguredHotkeysIndependently() {
        let plan = HotkeyManager.registrationPlan(
            toggleConfig: .defaultToggle,
            pushToTalkConfig: .defaultPushToTalk
        )

        XCTAssertEqual(
            plan,
            HotkeyRegistrationPlan(registerToggle: true, registerPushToTalk: true)
        )
    }

    func testEmptyToggleDoesNotDisablePushToTalk() {
        let plan = HotkeyManager.registrationPlan(
            toggleConfig: .empty,
            pushToTalkConfig: .defaultPushToTalk
        )

        XCTAssertEqual(
            plan,
            HotkeyRegistrationPlan(registerToggle: false, registerPushToTalk: true)
        )
    }

    func testEmptyPushToTalkDoesNotDisableToggle() {
        let plan = HotkeyManager.registrationPlan(
            toggleConfig: .defaultToggle,
            pushToTalkConfig: .empty
        )

        XCTAssertEqual(
            plan,
            HotkeyRegistrationPlan(registerToggle: true, registerPushToTalk: false)
        )
    }
}
