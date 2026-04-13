import Core
import Foundation

final class TypingMetricsAggregator {
    private struct TimedToken {
        let token: String
        let timestamp: Date
    }

    private let maxBigramLatencyMilliseconds: Double
    private let maxTrigramLatencyMilliseconds: Double
    private var recentTokens: [TimedToken]

    private(set) var metrics: AggregateTypingMetrics

    init(
        initialMetrics: AggregateTypingMetrics = AggregateTypingMetrics(),
        maxBigramLatencyMilliseconds: Double = 2_500,
        maxTrigramLatencyMilliseconds: Double = 5_000
    ) {
        self.metrics = initialMetrics
        self.maxBigramLatencyMilliseconds = maxBigramLatencyMilliseconds
        self.maxTrigramLatencyMilliseconds = maxTrigramLatencyMilliseconds
        self.recentTokens = []
    }

    func recordIncludedEvent(
        token: String?,
        isBackspace: Bool,
        timestamp: Date
    ) {
        metrics.totalKeyDownEvents += 1
        if isBackspace {
            metrics.totalBackspaces += 1
        }
        metrics.lastIncludedEventAt = timestamp
        metrics.lastUpdatedAt = timestamp

        guard let token else {
            recentTokens.removeAll(keepingCapacity: true)
            return
        }

        let currentToken = TimedToken(token: token, timestamp: timestamp)

        if let previousToken = recentTokens.last {
            incrementBigram(from: previousToken, to: currentToken)
        }

        if recentTokens.count >= 2 {
            incrementTrigram(
                first: recentTokens[recentTokens.count - 2],
                second: recentTokens[recentTokens.count - 1],
                third: currentToken
            )
        }

        recentTokens.append(currentToken)
        if recentTokens.count > 2 {
            recentTokens.removeFirst(recentTokens.count - 2)
        }
    }

    func recordExcludedEvent(timestamp: Date) {
        metrics.excludedEventCount += 1
        metrics.lastUpdatedAt = timestamp
        recentTokens.removeAll(keepingCapacity: true)
    }

    func reset() {
        metrics = AggregateTypingMetrics()
        recentTokens.removeAll(keepingCapacity: true)
    }

    private func incrementBigram(from first: TimedToken, to second: TimedToken) {
        let gram = first.token + second.token
        let latencyMilliseconds = second.timestamp.timeIntervalSince(first.timestamp) * 1_000

        var aggregate = metrics.bigramCounts[gram, default: NGramAggregate()]
        aggregate.count += 1

        if latencyMilliseconds >= 0, latencyMilliseconds <= maxBigramLatencyMilliseconds {
            aggregate.latencySampleCount += 1
            aggregate.totalLatencyMilliseconds += latencyMilliseconds
        }

        metrics.bigramCounts[gram] = aggregate
    }

    private func incrementTrigram(
        first: TimedToken,
        second: TimedToken,
        third: TimedToken
    ) {
        let gram = first.token + second.token + third.token
        let latencyMilliseconds = third.timestamp.timeIntervalSince(first.timestamp) * 1_000

        var aggregate = metrics.trigramCounts[gram, default: NGramAggregate()]
        aggregate.count += 1

        if latencyMilliseconds >= 0, latencyMilliseconds <= maxTrigramLatencyMilliseconds {
            aggregate.latencySampleCount += 1
            aggregate.totalLatencyMilliseconds += latencyMilliseconds
        }

        metrics.trigramCounts[gram] = aggregate
    }
}
