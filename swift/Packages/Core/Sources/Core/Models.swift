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
    case tapUnavailable
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

public struct CaptureDashboardState: Equatable, Sendable {
    public var permissionState: InputMonitoringPermissionState
    public var captureActivityState: CaptureActivityState
    public var isPaused: Bool
    public var tapHealth: TapHealth
    public var aggregateMetrics: AggregateTypingMetrics
    public var exclusionStatus: ExclusionStatus
    public var debugPreviewText: String
    public var recentEvents: [DebugPreviewEvent]
    public var guidanceText: String

    public init(
        permissionState: InputMonitoringPermissionState = .unknown,
        captureActivityState: CaptureActivityState = .needsPermission,
        isPaused: Bool = false,
        tapHealth: TapHealth = TapHealth(),
        aggregateMetrics: AggregateTypingMetrics = AggregateTypingMetrics(),
        exclusionStatus: ExclusionStatus = ExclusionStatus(),
        debugPreviewText: String = "",
        recentEvents: [DebugPreviewEvent] = [],
        guidanceText: String = "Grant Input Monitoring to start the listen-only keyboard tap."
    ) {
        self.permissionState = permissionState
        self.captureActivityState = captureActivityState
        self.isPaused = isPaused
        self.tapHealth = tapHealth
        self.aggregateMetrics = aggregateMetrics
        self.exclusionStatus = exclusionStatus
        self.debugPreviewText = debugPreviewText
        self.recentEvents = recentEvents
        self.guidanceText = guidanceText
    }
}
