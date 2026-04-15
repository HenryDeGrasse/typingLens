import Foundation
import Testing
@testable import Core

@Suite("TypingProfileSummary")
struct TypingProfileSummaryTests {
    @Test func defaultsAreZeroAndEmpty() {
        let summary = TypingProfileSummary()
        #expect(summary.includedKeyDownCount == 0)
        #expect(summary.backspaceDensity == 0)
        #expect(summary.averageBurstLength == 0)
        #expect(summary.lastIncludedEventAt == nil)
    }

    @Test func backspaceDensityIsBackspacesOverIncludedKeys() {
        var summary = TypingProfileSummary()
        summary.includedKeyDownCount = 100
        summary.backspaceCount = 8
        #expect(abs(summary.backspaceDensity - 0.08) < 0.0001)
    }

    @Test func averageBurstLengthIsTotalBurstKeysOverBurstCount() {
        var summary = TypingProfileSummary()
        summary.burstCount = 4
        summary.totalBurstKeyCount = 80
        #expect(summary.averageBurstLength == 20)
    }

    @Test func flightStatsForHandPatternFallsBackToEmptyHistogramSummary() {
        let summary = TypingProfileSummary()
        let stats = summary.flightStats(for: .sameHand)
        #expect(stats.sampleCount == 0)
        #expect(stats.p50Milliseconds == nil)
    }

    @Test func flightStatsForBucketReadsUnderlyingHistogram() {
        var summary = TypingProfileSummary()
        var histogram = DistributionHistogram.timing()
        for _ in 0..<10 { histogram.insert(120) }
        summary.flightByDistanceBucket[DistanceBucket.near.rawValue] = histogram

        let stats = summary.flightStats(for: .near)
        #expect(stats.sampleCount == 10)
        #expect(stats.p50Milliseconds != nil)
    }

    @Test func mergeAccumulatesScalarsAndHistogramsAndKeepsLatestTimestamp() {
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)

        var lhs = TypingProfileSummary()
        lhs.includedKeyDownCount = 50
        lhs.backspaceCount = 4
        lhs.lastIncludedEventAt = earlier
        lhs.flightHistogram.insert(80)

        var rhs = TypingProfileSummary()
        rhs.includedKeyDownCount = 30
        rhs.backspaceCount = 3
        rhs.lastIncludedEventAt = later
        rhs.flightHistogram.insert(100)

        lhs.merge(rhs)

        #expect(lhs.includedKeyDownCount == 80)
        #expect(lhs.backspaceCount == 7)
        #expect(lhs.lastIncludedEventAt == later)
        #expect(lhs.flightHistogram.sampleCount == 2)
    }

    @Test func mergeKeepsExistingTimestampWhenOtherIsOlder() {
        let later = Date(timeIntervalSince1970: 2_000)
        let earlier = Date(timeIntervalSince1970: 1_000)

        var lhs = TypingProfileSummary()
        lhs.lastIncludedEventAt = later

        var rhs = TypingProfileSummary()
        rhs.lastIncludedEventAt = earlier

        lhs.merge(rhs)
        #expect(lhs.lastIncludedEventAt == later)
    }

    @Test func mergeOfHistogramDictionariesAddsMissingKeys() {
        var lhs = TypingProfileSummary()
        var rhs = TypingProfileSummary()
        var histogram = DistributionHistogram.timing()
        histogram.insert(100)
        rhs.flightByHandPattern[HandTransitionPattern.crossHand.rawValue] = histogram

        lhs.merge(rhs)
        #expect(lhs.flightByHandPattern[HandTransitionPattern.crossHand.rawValue]?.sampleCount == 1)
    }

    @Test func codableRoundTripPreservesShape() throws {
        var summary = TypingProfileSummary()
        summary.includedKeyDownCount = 42
        summary.backspaceCount = 3
        summary.flightHistogram.insert(120)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(summary)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TypingProfileSummary.self, from: data)

        #expect(decoded.includedKeyDownCount == 42)
        #expect(decoded.flightHistogram.sampleCount == 1)
    }
}
