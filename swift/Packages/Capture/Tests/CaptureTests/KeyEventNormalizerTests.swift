import CoreGraphics
import Foundation
import Testing
@testable import Capture
@testable import Core

@Suite("KeyEventNormalizer")
struct KeyEventNormalizerTests {
    @Test func lowercaseLetterIsClassifiedAsLetterAndProfileEligible() {
        let event = makeEvent(keyCode: 0, renderedValue: "a", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .letter)
        #expect(classified.shouldUseInProfile)
        #expect(classified.countsAsPrintable)
        #expect(classified.advancedAggregateToken == "a")
    }

    @Test func uppercaseLetterStillClassifiedAsLetter() {
        let event = makeEvent(keyCode: 0, renderedValue: "A", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .letter)
    }

    @Test func digitIsClassifiedAsNumber() {
        let event = makeEvent(keyCode: 18, renderedValue: "1", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .number)
        #expect(classified.countsAsPrintable)
    }

    @Test func spaceTokenClassifiedAsWhitespace() {
        let event = makeEvent(keyCode: 49, renderedValue: "␠", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .whitespace)
        #expect(classified.shouldUseInProfile)
    }

    @Test func returnTokenClassifiedAsReturnKey() {
        let event = makeEvent(keyCode: 36, renderedValue: "↩︎", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .returnKey)
    }

    @Test func backspaceFlagIsRespectedRegardlessOfRender() {
        let event = makeEvent(keyCode: 51, renderedValue: "⌫", phase: .keyDown, isBackspace: true)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .backspace)
        #expect(classified.isBackspace)
    }

    @Test func modifierKeysClassifiedAsModifierAndExcludedFromProfile() {
        let event = makeEvent(keyCode: 56, renderedValue: "⇧", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .modifier)
        #expect(!classified.shouldUseInProfile)
    }

    @Test func navigationKeyClassifiedAsNavigation() {
        let event = makeEvent(keyCode: 123, renderedValue: "←", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .navigation)
        #expect(!classified.shouldUseInProfile)
    }

    @Test func commandModifiedKeyIsExcludedFromProfileAndAggregateToken() {
        let event = makeEvent(keyCode: 0, renderedValue: "a", phase: .keyDown, flags: .maskCommand)
        let classified = KeyEventNormalizer.classify(event)
        #expect(!classified.shouldUseInProfile)
        #expect(classified.advancedAggregateToken == nil)
    }

    @Test func autoRepeatExcludedFromProfile() {
        let event = makeEvent(keyCode: 0, renderedValue: "a", phase: .keyDown, isAutoRepeat: true)
        let classified = KeyEventNormalizer.classify(event)
        #expect(!classified.shouldUseInProfile)
        #expect(classified.advancedAggregateToken == nil)
    }

    @Test func keyUpNeverContributesToProfile() {
        let event = makeEvent(keyCode: 0, renderedValue: "a", phase: .keyUp)
        let classified = KeyEventNormalizer.classify(event)
        #expect(!classified.shouldUseInProfile)
        #expect(classified.advancedAggregateToken == nil)
    }

    @Test func unknownRenderClassifiesAsOther() {
        let event = makeEvent(keyCode: 999, renderedValue: "[keyCode:999]", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .other)
    }

    @Test func singlePunctuationCharacterClassifiedAsPunctuation() {
        let event = makeEvent(keyCode: 47, renderedValue: ".", phase: .keyDown)
        let classified = KeyEventNormalizer.classify(event)
        #expect(classified.keyClass == .punctuation)
        #expect(classified.advancedAggregateToken == ".")
    }

    private func makeEvent(
        keyCode: Int64,
        renderedValue: String,
        phase: ObservedKeyEventPhase,
        isBackspace: Bool = false,
        flags: CGEventFlags = [],
        isAutoRepeat: Bool = false
    ) -> ObservedKeyEvent {
        ObservedKeyEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            phase: phase,
            keyCode: keyCode,
            keyboardType: 41,
            deviceID: 1,
            kind: phase == .keyDown ? "keyDown" : "keyUp",
            renderedValue: renderedValue,
            isBackspace: isBackspace,
            flags: flags,
            isAutoRepeat: isAutoRepeat
        )
    }
}
