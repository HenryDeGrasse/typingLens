import Testing
@testable import Core

@Suite("DistributionHistogram")
struct DistributionHistogramTests {
    @Test func emptyHistogramHasNoSamplesOrPercentiles() {
        let histogram = DistributionHistogram(boundaries: [10, 20, 30])
        #expect(histogram.sampleCount == 0)
        #expect(histogram.median == nil)
        #expect(histogram.p90 == nil)
        #expect(histogram.iqr == nil)
    }

    @Test func insertIncrementsSampleCountInRightBucket() {
        var histogram = DistributionHistogram(boundaries: [10, 20, 30])
        histogram.insert(5)   // bucket 0 (≤10)
        histogram.insert(15)  // bucket 1 (10–20)
        histogram.insert(25)  // bucket 2 (20–30)
        histogram.insert(50)  // bucket 3 (>30)

        #expect(histogram.sampleCount == 4)
        #expect(histogram.counts == [1, 1, 1, 1])
    }

    @Test func valueOnBoundaryFallsIntoLowerBucket() {
        var histogram = DistributionHistogram(boundaries: [10, 20])
        histogram.insert(10)
        histogram.insert(20)
        #expect(histogram.counts == [1, 1, 0])
    }

    @Test func medianReturnsRepresentativeMidValue() {
        var histogram = DistributionHistogram(boundaries: [10, 20, 30, 40])
        for _ in 0..<10 { histogram.insert(15) }
        #expect(histogram.median == 15)
    }

    @Test func p90SkewsTowardLargerBuckets() {
        var histogram = DistributionHistogram(boundaries: [10, 20, 30, 40])
        for _ in 0..<8 { histogram.insert(15) }
        for _ in 0..<2 { histogram.insert(35) }
        let p90 = try? #require(histogram.p90)
        #expect((p90 ?? 0) >= 25)
    }

    @Test func iqrReturnsP75MinusP25() {
        var histogram = DistributionHistogram(boundaries: [10, 20, 30, 40, 50])
        for _ in 0..<5 { histogram.insert(15) }
        for _ in 0..<5 { histogram.insert(45) }
        #expect(histogram.iqr != nil)
        #expect((histogram.iqr ?? 0) > 0)
    }

    @Test func mergeAddsCountsAcrossBuckets() {
        var lhs = DistributionHistogram(boundaries: [10, 20])
        lhs.insert(5)
        lhs.insert(15)

        var rhs = DistributionHistogram(boundaries: [10, 20])
        rhs.insert(5)
        rhs.insert(25)

        lhs.merge(rhs)
        #expect(lhs.sampleCount == 4)
        #expect(lhs.counts == [2, 1, 1])
    }

    @Test func mergeRefusesIncompatibleBoundaries() {
        var lhs = DistributionHistogram(boundaries: [10, 20])
        lhs.insert(5)

        var rhs = DistributionHistogram(boundaries: [10, 20, 30])
        rhs.insert(5)

        lhs.merge(rhs)
        #expect(lhs.sampleCount == 1, "Merge should reject mismatched boundaries")
    }

    @Test func percentileClampedBelowZero() {
        var histogram = DistributionHistogram(boundaries: [10, 20])
        for _ in 0..<5 { histogram.insert(15) }
        #expect(histogram.percentile(-1) == histogram.percentile(0))
    }

    @Test func percentileClampedAboveOne() {
        var histogram = DistributionHistogram(boundaries: [10, 20])
        for _ in 0..<5 { histogram.insert(15) }
        #expect(histogram.percentile(1.5) == histogram.percentile(1))
    }

    @Test func entriesProvideLabelsForAllBuckets() {
        let histogram = DistributionHistogram(boundaries: [10, 20])
        let entries = histogram.entries()
        #expect(entries.count == 3)
        #expect(entries[0].label == "≤10")
        #expect(entries[1].label == "10–20")
        #expect(entries[2].label == ">20")
    }

    @Test func timingFactoryUsesExpectedBoundaries() {
        let histogram = DistributionHistogram.timing()
        #expect(histogram.boundaries.contains(40))
        #expect(histogram.boundaries.contains(2_000))
    }
}
