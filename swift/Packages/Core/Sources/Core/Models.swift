import Foundation

public enum InputMonitoringPermissionState: String, Codable, Sendable {
    case unknown
    case granted
    case denied
}

public enum CaptureActivityState: String, Codable, Sendable {
    case needsPermission
    case permissionDenied
    case recording
    case paused
    case secureInputBlocked
    case tapUnavailable
}

public enum SecureInputState: String, Codable, Sendable {
    case unavailable
    case disabled
    case enabled
}

public enum KeyClass: String, Codable, CaseIterable, Sendable {
    case letter
    case number
    case punctuation
    case whitespace
    case returnKey
    case backspace
    case modifier
    case navigation
    case other
}

public enum KeyHand: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case neutral
    case unknown
}

public enum HandTransitionPattern: String, Codable, CaseIterable, Sendable {
    case sameHand
    case crossHand
    case involvesNeutral
    case unknown
}

public enum DistanceBucket: String, Codable, CaseIterable, Sendable {
    case sameKey
    case near
    case medium
    case far
    case unknown
}

public enum ProfileConfidenceState: String, Codable, Sendable {
    case warmingUp
    case buildingBaseline
    case ready
}

public struct TapHealth: Equatable, Sendable {
    public var isInstalled: Bool
    public var isEnabled: Bool
    public var lastEventAt: Date?
    public var statusNote: String

    public init(
        isInstalled: Bool = false,
        isEnabled: Bool = false,
        lastEventAt: Date? = nil,
        statusNote: String = "Tap not installed"
    ) {
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.lastEventAt = lastEventAt
        self.statusNote = statusNote
    }
}

public struct DebugPreviewEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: String
    public let renderedValue: String
    public let keyCode: Int64

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        kind: String,
        renderedValue: String,
        keyCode: Int64
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.renderedValue = renderedValue
        self.keyCode = keyCode
    }
}

public struct DistributionHistogram: Equatable, Codable, Sendable {
    public let boundaries: [Double]
    public var counts: [Int]

    public init(
        boundaries: [Double],
        counts: [Int]? = nil
    ) {
        self.boundaries = boundaries.sorted()
        self.counts = counts ?? Array(repeating: 0, count: boundaries.count + 1)
    }

    public var sampleCount: Int {
        counts.reduce(0, +)
    }

    public mutating func insert(_ value: Double) {
        let insertionIndex = boundaries.firstIndex(where: { value <= $0 }) ?? boundaries.count
        counts[insertionIndex] += 1
    }

    public mutating func merge(_ other: DistributionHistogram) {
        guard boundaries == other.boundaries, counts.count == other.counts.count else {
            return
        }

        for index in counts.indices {
            counts[index] += other.counts[index]
        }
    }

    public func percentile(_ percentile: Double) -> Double? {
        guard sampleCount > 0 else { return nil }

        let clampedPercentile = min(max(percentile, 0), 1)
        let target = Int(ceil(clampedPercentile * Double(sampleCount)))
        var runningTotal = 0

        for index in counts.indices {
            runningTotal += counts[index]
            if runningTotal >= max(target, 1) {
                return representativeValue(forBucketAt: index)
            }
        }

        return representativeValue(forBucketAt: counts.indices.last ?? 0)
    }

    public var median: Double? {
        percentile(0.5)
    }

    public var p90: Double? {
        percentile(0.9)
    }

    public var iqr: Double? {
        guard let q1 = percentile(0.25), let q3 = percentile(0.75) else {
            return nil
        }
        return q3 - q1
    }

    public func entries() -> [HistogramEntry] {
        counts.indices.map { index in
            HistogramEntry(
                label: bucketLabel(forBucketAt: index),
                value: counts[index]
            )
        }
    }

    private func representativeValue(forBucketAt index: Int) -> Double {
        if index == 0 {
            return boundaries.first ?? 0
        }

        if index == counts.count - 1 {
            return boundaries.last ?? 0
        }

        let lowerBound = boundaries[index - 1]
        let upperBound = boundaries[index]
        return (lowerBound + upperBound) / 2
    }

    private func bucketLabel(forBucketAt index: Int) -> String {
        if boundaries.isEmpty {
            return "0"
        }

        if index == 0 {
            return "≤\(Int(boundaries[0]))"
        }

        if index == counts.count - 1 {
            return ">\(Int(boundaries[index - 1]))"
        }

        return "\(Int(boundaries[index - 1]))–\(Int(boundaries[index]))"
    }

    public static func timing() -> DistributionHistogram {
        DistributionHistogram(boundaries: [40, 60, 80, 100, 130, 160, 200, 250, 320, 400, 500, 650, 800, 1_000, 1_300, 1_600, 2_000, 2_500, 3_500])
    }

    public static func pauseTiming() -> DistributionHistogram {
        DistributionHistogram(boundaries: [250, 500, 750, 1_000, 1_500, 2_000, 3_000, 5_000, 10_000, 30_000])
    }

    public static func burstLengths() -> DistributionHistogram {
        DistributionHistogram(boundaries: [5, 10, 20, 30, 45, 60, 90, 120, 180])
    }

    public static func correctionBurstLengths() -> DistributionHistogram {
        DistributionHistogram(boundaries: [1, 2, 3, 5, 8, 12, 20])
    }
}

public struct HistogramEntry: Identifiable, Equatable, Sendable {
    public var id: String { label }

    public let label: String
    public let value: Int

    public init(label: String, value: Int) {
        self.label = label
        self.value = value
    }
}

public struct TimingStatsSummary: Equatable, Sendable {
    public let sampleCount: Int
    public let p50Milliseconds: Double?
    public let p90Milliseconds: Double?
    public let iqrMilliseconds: Double?

    public init(histogram: DistributionHistogram) {
        self.sampleCount = histogram.sampleCount
        self.p50Milliseconds = histogram.median
        self.p90Milliseconds = histogram.p90
        self.iqrMilliseconds = histogram.iqr
    }
}

public struct TypingProfileSummary: Equatable, Codable, Sendable {
    public var includedKeyDownCount: Int
    public var printableKeyDownCount: Int
    public var backspaceCount: Int
    public var heldDeleteBurstCount: Int
    public var excludedEventCount: Int
    public var sessionCount: Int
    public var burstCount: Int
    public var totalBurstKeyCount: Int
    public var dwellHistogram: DistributionHistogram
    public var flightHistogram: DistributionHistogram
    public var pauseHistogram: DistributionHistogram
    public var burstLengthHistogram: DistributionHistogram
    public var correctionBurstHistogram: DistributionHistogram
    public var heldDeleteDurationHistogram: DistributionHistogram
    public var preCorrectionFlightHistogram: DistributionHistogram
    public var recoveryFlightHistogram: DistributionHistogram
    public var dwellByKeyClass: [String: DistributionHistogram]
    public var flightByHandPattern: [String: DistributionHistogram]
    public var flightByDistanceBucket: [String: DistributionHistogram]
    public var lastIncludedEventAt: Date?
    public var lastUpdatedAt: Date?

    public init(
        includedKeyDownCount: Int = 0,
        printableKeyDownCount: Int = 0,
        backspaceCount: Int = 0,
        heldDeleteBurstCount: Int = 0,
        excludedEventCount: Int = 0,
        sessionCount: Int = 0,
        burstCount: Int = 0,
        totalBurstKeyCount: Int = 0,
        dwellHistogram: DistributionHistogram = .timing(),
        flightHistogram: DistributionHistogram = .timing(),
        pauseHistogram: DistributionHistogram = .pauseTiming(),
        burstLengthHistogram: DistributionHistogram = .burstLengths(),
        correctionBurstHistogram: DistributionHistogram = .correctionBurstLengths(),
        heldDeleteDurationHistogram: DistributionHistogram = .pauseTiming(),
        preCorrectionFlightHistogram: DistributionHistogram = .timing(),
        recoveryFlightHistogram: DistributionHistogram = .timing(),
        dwellByKeyClass: [String: DistributionHistogram] = [:],
        flightByHandPattern: [String: DistributionHistogram] = [:],
        flightByDistanceBucket: [String: DistributionHistogram] = [:],
        lastIncludedEventAt: Date? = nil,
        lastUpdatedAt: Date? = nil
    ) {
        self.includedKeyDownCount = includedKeyDownCount
        self.printableKeyDownCount = printableKeyDownCount
        self.backspaceCount = backspaceCount
        self.heldDeleteBurstCount = heldDeleteBurstCount
        self.excludedEventCount = excludedEventCount
        self.sessionCount = sessionCount
        self.burstCount = burstCount
        self.totalBurstKeyCount = totalBurstKeyCount
        self.dwellHistogram = dwellHistogram
        self.flightHistogram = flightHistogram
        self.pauseHistogram = pauseHistogram
        self.burstLengthHistogram = burstLengthHistogram
        self.correctionBurstHistogram = correctionBurstHistogram
        self.heldDeleteDurationHistogram = heldDeleteDurationHistogram
        self.preCorrectionFlightHistogram = preCorrectionFlightHistogram
        self.recoveryFlightHistogram = recoveryFlightHistogram
        self.dwellByKeyClass = dwellByKeyClass
        self.flightByHandPattern = flightByHandPattern
        self.flightByDistanceBucket = flightByDistanceBucket
        self.lastIncludedEventAt = lastIncludedEventAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    public var backspaceDensity: Double {
        guard includedKeyDownCount > 0 else { return 0 }
        return Double(backspaceCount) / Double(includedKeyDownCount)
    }

    public var averageBurstLength: Double {
        guard burstCount > 0 else { return 0 }
        return Double(totalBurstKeyCount) / Double(burstCount)
    }

    public var dwellStats: TimingStatsSummary {
        TimingStatsSummary(histogram: dwellHistogram)
    }

    public var flightStats: TimingStatsSummary {
        TimingStatsSummary(histogram: flightHistogram)
    }

    public var pauseStats: TimingStatsSummary {
        TimingStatsSummary(histogram: pauseHistogram)
    }

    public var preCorrectionStats: TimingStatsSummary {
        TimingStatsSummary(histogram: preCorrectionFlightHistogram)
    }

    public var heldDeleteStats: TimingStatsSummary {
        TimingStatsSummary(histogram: heldDeleteDurationHistogram)
    }

    public var recoveryStats: TimingStatsSummary {
        TimingStatsSummary(histogram: recoveryFlightHistogram)
    }

    public func dwellStats(for keyClass: KeyClass) -> TimingStatsSummary {
        TimingStatsSummary(histogram: dwellByKeyClass[keyClass.rawValue, default: .timing()])
    }

    public func flightStats(for pattern: HandTransitionPattern) -> TimingStatsSummary {
        TimingStatsSummary(histogram: flightByHandPattern[pattern.rawValue, default: .timing()])
    }

    public func flightStats(for bucket: DistanceBucket) -> TimingStatsSummary {
        TimingStatsSummary(histogram: flightByDistanceBucket[bucket.rawValue, default: .timing()])
    }

    public mutating func merge(_ other: TypingProfileSummary) {
        includedKeyDownCount += other.includedKeyDownCount
        printableKeyDownCount += other.printableKeyDownCount
        backspaceCount += other.backspaceCount
        heldDeleteBurstCount += other.heldDeleteBurstCount
        excludedEventCount += other.excludedEventCount
        sessionCount += other.sessionCount
        burstCount += other.burstCount
        totalBurstKeyCount += other.totalBurstKeyCount
        dwellHistogram.merge(other.dwellHistogram)
        flightHistogram.merge(other.flightHistogram)
        pauseHistogram.merge(other.pauseHistogram)
        burstLengthHistogram.merge(other.burstLengthHistogram)
        correctionBurstHistogram.merge(other.correctionBurstHistogram)
        heldDeleteDurationHistogram.merge(other.heldDeleteDurationHistogram)
        preCorrectionFlightHistogram.merge(other.preCorrectionFlightHistogram)
        recoveryFlightHistogram.merge(other.recoveryFlightHistogram)

        Self.mergeHistogramDictionary(&dwellByKeyClass, other: other.dwellByKeyClass)
        Self.mergeHistogramDictionary(&flightByHandPattern, other: other.flightByHandPattern)
        Self.mergeHistogramDictionary(&flightByDistanceBucket, other: other.flightByDistanceBucket)

        if let otherLastIncludedEventAt = other.lastIncludedEventAt,
           lastIncludedEventAt.map({ otherLastIncludedEventAt > $0 }) ?? true {
            lastIncludedEventAt = otherLastIncludedEventAt
        }

        if let otherLastUpdatedAt = other.lastUpdatedAt,
           lastUpdatedAt.map({ otherLastUpdatedAt > $0 }) ?? true {
            lastUpdatedAt = otherLastUpdatedAt
        }
    }

    private static func mergeHistogramDictionary(
        _ target: inout [String: DistributionHistogram],
        other: [String: DistributionHistogram]
    ) {
        for (key, value) in other {
            var histogram = target[key] ?? value
            if target[key] != nil {
                histogram.merge(value)
            }
            target[key] = histogram
        }
    }
}

public struct ProfileInsight: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let detail: String

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String
    ) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public struct TypingProfileSnapshot: Equatable, Sendable {
    public var today: TypingProfileSummary
    public var baseline: TypingProfileSummary
    public var baselineDayCount: Int
    public var confidence: ProfileConfidenceState
    public var insights: [ProfileInsight]

    public init(
        today: TypingProfileSummary = TypingProfileSummary(),
        baseline: TypingProfileSummary = TypingProfileSummary(),
        baselineDayCount: Int = 0,
        confidence: ProfileConfidenceState = .warmingUp,
        insights: [ProfileInsight] = []
    ) {
        self.today = today
        self.baseline = baseline
        self.baselineDayCount = baselineDayCount
        self.confidence = confidence
        self.insights = insights
    }
}

public struct TrustState: Equatable, Sendable {
    public var secureInputState: SecureInputState
    public var profileStorePath: String
    public var manualExclusionsStorePath: String
    public var storesRawText: Bool
    public var storesLiteralNGrams: Bool
    public var note: String

    public init(
        secureInputState: SecureInputState = .unavailable,
        profileStorePath: String = "",
        manualExclusionsStorePath: String = "",
        storesRawText: Bool = false,
        storesLiteralNGrams: Bool = false,
        note: String = "Typing Lens stores profile summaries locally and keeps raw preview debug-only in memory."
    ) {
        self.secureInputState = secureInputState
        self.profileStorePath = profileStorePath
        self.manualExclusionsStorePath = manualExclusionsStorePath
        self.storesRawText = storesRawText
        self.storesLiteralNGrams = storesLiteralNGrams
        self.note = note
    }
}

public struct NGramAggregate: Equatable, Codable, Sendable {
    public var count: Int
    public var latencySampleCount: Int
    public var totalLatencyMilliseconds: Double

    public init(
        count: Int = 0,
        latencySampleCount: Int = 0,
        totalLatencyMilliseconds: Double = 0
    ) {
        self.count = count
        self.latencySampleCount = latencySampleCount
        self.totalLatencyMilliseconds = totalLatencyMilliseconds
    }

    public var averageLatencyMilliseconds: Double? {
        guard latencySampleCount > 0 else { return nil }
        return totalLatencyMilliseconds / Double(latencySampleCount)
    }
}

public struct RankedNGramMetric: Identifiable, Equatable, Sendable {
    public var id: String { gram }

    public let gram: String
    public let count: Int
    public let averageLatencyMilliseconds: Double?

    public init(
        gram: String,
        count: Int,
        averageLatencyMilliseconds: Double?
    ) {
        self.gram = gram
        self.count = count
        self.averageLatencyMilliseconds = averageLatencyMilliseconds
    }
}

public struct AggregateTypingMetrics: Equatable, Codable, Sendable {
    public var totalKeyDownEvents: Int
    public var totalBackspaces: Int
    public var excludedEventCount: Int
    public var bigramCounts: [String: NGramAggregate]
    public var trigramCounts: [String: NGramAggregate]
    public var lastIncludedEventAt: Date?
    public var lastUpdatedAt: Date?

    public init(
        totalKeyDownEvents: Int = 0,
        totalBackspaces: Int = 0,
        excludedEventCount: Int = 0,
        bigramCounts: [String: NGramAggregate] = [:],
        trigramCounts: [String: NGramAggregate] = [:],
        lastIncludedEventAt: Date? = nil,
        lastUpdatedAt: Date? = nil
    ) {
        self.totalKeyDownEvents = totalKeyDownEvents
        self.totalBackspaces = totalBackspaces
        self.excludedEventCount = excludedEventCount
        self.bigramCounts = bigramCounts
        self.trigramCounts = trigramCounts
        self.lastIncludedEventAt = lastIncludedEventAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    public var backspaceDensity: Double {
        guard totalKeyDownEvents > 0 else { return 0 }
        return Double(totalBackspaces) / Double(totalKeyDownEvents)
    }

    public func topBigrams(limit: Int = 6) -> [RankedNGramMetric] {
        rankedMetrics(from: bigramCounts, limit: limit)
    }

    public func topTrigrams(limit: Int = 6) -> [RankedNGramMetric] {
        rankedMetrics(from: trigramCounts, limit: limit)
    }

    private func rankedMetrics(
        from source: [String: NGramAggregate],
        limit: Int
    ) -> [RankedNGramMetric] {
        source
            .map { gram, aggregate in
                RankedNGramMetric(
                    gram: gram,
                    count: aggregate.count,
                    averageLatencyMilliseconds: aggregate.averageLatencyMilliseconds
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.gram < $1.gram
            }
            .prefix(limit)
            .map { $0 }
    }
}

public struct ObservedApplication: Identifiable, Equatable, Hashable, Sendable {
    public var id: String {
        bundleIdentifier ?? displayName
    }

    public let displayName: String
    public let bundleIdentifier: String?

    public init(
        displayName: String,
        bundleIdentifier: String?
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct ExcludedApplication: Identifiable, Equatable, Hashable, Codable, Sendable {
    public var id: String {
        bundleIdentifier
    }

    public let displayName: String
    public let bundleIdentifier: String

    public init(
        displayName: String,
        bundleIdentifier: String
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct ExclusionStatus: Equatable, Sendable {
    public var builtInExcludedApplications: [ExcludedApplication]
    public var manualExcludedApplications: [ExcludedApplication]
    public var excludedEventCount: Int
    public var lastExcludedAppName: String?
    public var lastObservedApplication: ObservedApplication?
    public var note: String?

    public init(
        builtInExcludedApplications: [ExcludedApplication] = [],
        manualExcludedApplications: [ExcludedApplication] = [],
        excludedEventCount: Int = 0,
        lastExcludedAppName: String? = nil,
        lastObservedApplication: ObservedApplication? = nil,
        note: String? = nil
    ) {
        self.builtInExcludedApplications = builtInExcludedApplications
        self.manualExcludedApplications = manualExcludedApplications
        self.excludedEventCount = excludedEventCount
        self.lastExcludedAppName = lastExcludedAppName
        self.lastObservedApplication = lastObservedApplication
        self.note = note
    }

    public var excludedAppDisplayNames: [String] {
        Array(Set((builtInExcludedApplications + manualExcludedApplications).map(\.displayName))).sorted()
    }

    public var excludedBundleIdentifiers: [String] {
        Array(Set((builtInExcludedApplications + manualExcludedApplications).map(\.bundleIdentifier))).sorted()
    }

    public var isLastObservedApplicationExcluded: Bool {
        guard let bundleIdentifier = lastObservedApplication?.bundleIdentifier else {
            return false
        }
        return excludedBundleIdentifiers.contains(bundleIdentifier)
    }
}

public enum SkillNodeLevel: String, Codable, Sendable {
    case leaf
    case aggregate
    case outcome
}

public enum SkillFamily: String, Codable, Sendable {
    case coordination
    case reach
    case repair
    case flow
    case rhythm
    case outcome
}

public enum SkillEdgeType: String, Codable, Sendable {
    case partOf
    case prerequisite
    case positiveTransfer
    case negativeInterference
    case observes
}

public enum LearnerStage: String, Codable, Sendable {
    case foundation
    case fluent
    case automatic
}

public enum WeaknessCategory: String, Codable, Sendable {
    case sameHandSequences
    case reachPrecision
    case accuracyRecovery
    case handHandoffs
    case flowConsistency
}

public enum WeaknessSeverity: String, Codable, Sendable {
    case mild
    case moderate
    case strong
}

public enum WeaknessConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum WeaknessLifecycleState: String, Codable, Sendable {
    case monitoring
    case confirmed
    case stabilizing
    case transferring
    case stable
}

public enum PracticeDrillFamily: String, Codable, Sendable {
    case sameHandLadders
    case reachAndReturn
    case alternationRails
    case accuracyReset
    case meteredFlow
    case mixedTransfer
}

public enum PracticeBlockKind: String, Codable, Sendable {
    case confirmatoryProbe
    case drill
    case postCheck
    case transferCheck
}

public struct SkillNode: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let family: SkillFamily
    public let level: SkillNodeLevel
    public let stage: LearnerStage
    public let detail: String

    public init(
        id: String,
        name: String,
        family: SkillFamily,
        level: SkillNodeLevel,
        stage: LearnerStage,
        detail: String
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.level = level
        self.stage = stage
        self.detail = detail
    }
}

public struct SkillEdge: Identifiable, Equatable, Sendable {
    public var id: String { "\(fromSkillID)->\(toSkillID):\(type.rawValue)" }

    public let fromSkillID: String
    public let toSkillID: String
    public let type: SkillEdgeType
    public let weight: Double
    public let note: String

    public init(
        fromSkillID: String,
        toSkillID: String,
        type: SkillEdgeType,
        weight: Double,
        note: String
    ) {
        self.fromSkillID = fromSkillID
        self.toSkillID = toSkillID
        self.type = type
        self.weight = weight
        self.note = note
    }
}

public struct SkillDimensionState: Equatable, Codable, Sendable {
    public var control: Double
    public var automaticity: Double
    public var consistency: Double
    public var stability: Double

    public init(
        control: Double = 0,
        automaticity: Double = 0,
        consistency: Double = 0,
        stability: Double = 0
    ) {
        self.control = control
        self.automaticity = automaticity
        self.consistency = consistency
        self.stability = stability
    }
}

public struct StudentSkillState: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let current: SkillDimensionState
    public let target: SkillDimensionState
    public let confidence: WeaknessConfidence
    public let evidenceCount: Int
    public let note: String

    public init(
        id: String,
        title: String,
        current: SkillDimensionState,
        target: SkillDimensionState,
        confidence: WeaknessConfidence,
        evidenceCount: Int,
        note: String
    ) {
        self.id = id
        self.title = title
        self.current = current
        self.target = target
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.note = note
    }
}

public struct WeaknessAssessment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let category: WeaknessCategory
    public let title: String
    public let summary: String
    public let severity: WeaknessSeverity
    public let confidence: WeaknessConfidence
    public let lifecycleState: WeaknessLifecycleState
    public let supportingSignals: [String]
    public let targetSkillIDs: [String]
    public let recommendedDrill: PracticeDrillFamily
    public let rationale: String

    public init(
        id: UUID = UUID(),
        category: WeaknessCategory,
        title: String,
        summary: String,
        severity: WeaknessSeverity,
        confidence: WeaknessConfidence,
        lifecycleState: WeaknessLifecycleState,
        supportingSignals: [String],
        targetSkillIDs: [String],
        recommendedDrill: PracticeDrillFamily,
        rationale: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.severity = severity
        self.confidence = confidence
        self.lifecycleState = lifecycleState
        self.supportingSignals = supportingSignals
        self.targetSkillIDs = targetSkillIDs
        self.recommendedDrill = recommendedDrill
        self.rationale = rationale
    }
}

public struct PracticeBlock: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: PracticeBlockKind
    public let title: String
    public let detail: String
    public let durationSeconds: Int
    public let drillFamily: PracticeDrillFamily?
    public let targetSkillIDs: [String]

    public init(
        id: UUID = UUID(),
        kind: PracticeBlockKind,
        title: String,
        detail: String,
        durationSeconds: Int,
        drillFamily: PracticeDrillFamily?,
        targetSkillIDs: [String]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.durationSeconds = durationSeconds
        self.drillFamily = drillFamily
        self.targetSkillIDs = targetSkillIDs
    }
}

public struct PracticeSessionPlan: Equatable, Sendable {
    public let primaryFocusTitle: String
    public let rationale: String
    public let blocks: [PracticeBlock]
    public let followUp: String

    public init(
        primaryFocusTitle: String,
        rationale: String,
        blocks: [PracticeBlock],
        followUp: String
    ) {
        self.primaryFocusTitle = primaryFocusTitle
        self.rationale = rationale
        self.blocks = blocks
        self.followUp = followUp
    }
}

public struct LearningModelSnapshot: Equatable, Sendable {
    public var skillNodes: [SkillNode]
    public var skillEdges: [SkillEdge]
    public var studentStates: [StudentSkillState]
    public var weaknesses: [WeaknessAssessment]
    public var primaryWeakness: WeaknessAssessment?
    public var recommendedSession: PracticeSessionPlan?

    public init(
        skillNodes: [SkillNode] = [],
        skillEdges: [SkillEdge] = [],
        studentStates: [StudentSkillState] = [],
        weaknesses: [WeaknessAssessment] = [],
        primaryWeakness: WeaknessAssessment? = nil,
        recommendedSession: PracticeSessionPlan? = nil
    ) {
        self.skillNodes = skillNodes
        self.skillEdges = skillEdges
        self.studentStates = studentStates
        self.weaknesses = weaknesses
        self.primaryWeakness = primaryWeakness
        self.recommendedSession = recommendedSession
    }
}

public struct CaptureDashboardState: Equatable, Sendable {
    public var permissionState: InputMonitoringPermissionState
    public var captureActivityState: CaptureActivityState
    public var isPaused: Bool
    public var tapHealth: TapHealth
    public var profileSnapshot: TypingProfileSnapshot
    public var learningModel: LearningModelSnapshot
    public var advancedDiagnostics: AggregateTypingMetrics
    public var trustState: TrustState
    public var exclusionStatus: ExclusionStatus
    public var debugPreviewText: String
    public var recentEvents: [DebugPreviewEvent]
    public var guidanceText: String

    public init(
        permissionState: InputMonitoringPermissionState = .unknown,
        captureActivityState: CaptureActivityState = .needsPermission,
        isPaused: Bool = false,
        tapHealth: TapHealth = TapHealth(),
        profileSnapshot: TypingProfileSnapshot = TypingProfileSnapshot(),
        learningModel: LearningModelSnapshot = LearningModelSnapshot(),
        advancedDiagnostics: AggregateTypingMetrics = AggregateTypingMetrics(),
        trustState: TrustState = TrustState(),
        exclusionStatus: ExclusionStatus = ExclusionStatus(),
        debugPreviewText: String = "",
        recentEvents: [DebugPreviewEvent] = [],
        guidanceText: String = "Grant Input Monitoring to start the listen-only keyboard tap."
    ) {
        self.permissionState = permissionState
        self.captureActivityState = captureActivityState
        self.isPaused = isPaused
        self.tapHealth = tapHealth
        self.profileSnapshot = profileSnapshot
        self.learningModel = learningModel
        self.advancedDiagnostics = advancedDiagnostics
        self.trustState = trustState
        self.exclusionStatus = exclusionStatus
        self.debugPreviewText = debugPreviewText
        self.recentEvents = recentEvents
        self.guidanceText = guidanceText
    }
}
