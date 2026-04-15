import Testing
@testable import Capture
@testable import Core

@Suite("KeyGeometryMap")
struct KeyGeometryMapTests {
    private let keyA: Int64 = 0
    private let keyS: Int64 = 1
    private let keyJ: Int64 = 38
    private let keyQ: Int64 = 12
    private let keyP: Int64 = 35
    private let space: Int64 = 49
    private let unknown: Int64 = 999

    @Test func homeRowSameLetterIsSameKey() {
        #expect(KeyGeometryMap.distanceBucket(from: keyA, to: keyA) == .sameKey)
    }

    @Test func adjacentLettersAreNear() {
        #expect(KeyGeometryMap.distanceBucket(from: keyA, to: keyS) == .near)
    }

    @Test func farLettersClassifiedAsFar() {
        #expect(KeyGeometryMap.distanceBucket(from: keyA, to: keyP) == .far)
    }

    @Test func unknownKeyCodeReturnsUnknownDistance() {
        #expect(KeyGeometryMap.distanceBucket(from: keyA, to: unknown) == .unknown)
        #expect(KeyGeometryMap.distanceBucket(from: unknown, to: keyA) == .unknown)
    }

    @Test func sameHandTransitionDetected() {
        #expect(KeyGeometryMap.handPattern(from: keyA, to: keyS) == .sameHand)
    }

    @Test func crossHandTransitionDetected() {
        #expect(KeyGeometryMap.handPattern(from: keyA, to: keyJ) == .crossHand)
    }

    @Test func neutralKeyTransitionFlaggedAsInvolvesNeutral() {
        #expect(KeyGeometryMap.handPattern(from: space, to: keyA) == .involvesNeutral)
        #expect(KeyGeometryMap.handPattern(from: keyA, to: space) == .involvesNeutral)
    }

    @Test func unknownKeyCodeProducesUnknownPattern() {
        #expect(KeyGeometryMap.handPattern(from: keyA, to: unknown) == .unknown)
    }

    @Test func geometryAvailableForCommonLetters() {
        #expect(KeyGeometryMap.geometry(for: keyA) != nil)
        #expect(KeyGeometryMap.geometry(for: keyJ) != nil)
        #expect(KeyGeometryMap.geometry(for: keyQ) != nil)
    }

    @Test func geometryNilForUnknownKeyCode() {
        #expect(KeyGeometryMap.geometry(for: unknown) == nil)
    }
}
