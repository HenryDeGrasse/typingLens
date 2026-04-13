import Foundation

public enum InputMonitoringPermissionState: String, Codable, Sendable {
    case unknown
    case granted
    case denied
}

public struct CaptureCounters: Equatable, Sendable {
    public var totalKeyDownEvents: Int
    public var totalBackspaces: Int

    public init(
        totalKeyDownEvents: Int = 0,
        totalBackspaces: Int = 0
    ) {
        self.totalKeyDownEvents = totalKeyDownEvents
        self.totalBackspaces = totalBackspaces
    }
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

public struct CaptureDashboardState: Equatable, Sendable {
    public var permissionState: InputMonitoringPermissionState
    public var isPaused: Bool
    public var counters: CaptureCounters
    public var tapHealth: TapHealth
    public var debugPreviewText: String
    public var recentEvents: [DebugPreviewEvent]
    public var guidanceText: String

    public init(
        permissionState: InputMonitoringPermissionState = .unknown,
        isPaused: Bool = false,
        counters: CaptureCounters = CaptureCounters(),
        tapHealth: TapHealth = TapHealth(),
        debugPreviewText: String = "",
        recentEvents: [DebugPreviewEvent] = [],
        guidanceText: String = "Grant Input Monitoring to start the listen-only keyboard tap."
    ) {
        self.permissionState = permissionState
        self.isPaused = isPaused
        self.counters = counters
        self.tapHealth = tapHealth
        self.debugPreviewText = debugPreviewText
        self.recentEvents = recentEvents
        self.guidanceText = guidanceText
    }
}
