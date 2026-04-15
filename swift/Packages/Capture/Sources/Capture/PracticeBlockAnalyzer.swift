import Core
import Foundation

enum PracticeBlockAnalyzer {
    private struct EpisodeSummary {
        var corrected = 0
        var uncorrected = 0
        var recoveryLatencies: [Double] = []
    }

    private struct SampledTransition {
        let milliseconds: Double
        let pattern: HandTransitionPattern
        let distance: DistanceBucket
    }

    static func metrics(for block: PracticeRuntimeEngine.RuntimeBlockState) -> [PracticeBlockMetricSnapshot] {
        let transitions = sampledTransitions(for: block)
        let allFlights = transitions.map(\.milliseconds)
        let sameHandFlights = transitions.filter { $0.pattern == .sameHand }.map(\.milliseconds)
        let crossHandFlights = transitions.filter { $0.pattern == .crossHand }.map(\.milliseconds)
        let farFlights = transitions.filter { $0.distance == .far }.map(\.milliseconds)
        let nearFlights = transitions.filter { $0.distance == .near || $0.distance == .medium }.map(\.milliseconds)
        let charsEntered = block.correctCharacterCount + block.incorrectCharacterCount
        let elapsedSeconds = max(Double(block.elapsedSeconds), 1)
        let errorRate = charsEntered > 0 ? Double(block.incorrectCharacterCount) / Double(charsEntered) : 0
        let charsPerSecond = Double(block.correctCharacterCount) / elapsedSeconds
        let episodeSummary = summarizeEpisodes(for: block)

        return [
            metric("flightMedianMs", cohort: "overall", samples: allFlights, direction: .lowerIsBetter),
            metric("cadenceIQRMs", cohort: "overall", samples: allFlights, useDispersion: true, direction: .lowerIsBetter),
            metric("flightMedianMs", cohort: "sameHand", samples: sameHandFlights, direction: .lowerIsBetter),
            metric("flightMedianMs", cohort: "crossHand", samples: crossHandFlights, direction: .lowerIsBetter),
            metric("flightMedianMs", cohort: "farDistance", samples: farFlights, direction: .lowerIsBetter),
            metric("flightMedianMs", cohort: "nearDistance", samples: nearFlights, direction: .lowerIsBetter),
            PracticeBlockMetricSnapshot(
                metricKey: "incorrectRate",
                cohortKey: "overall",
                sampleCount: charsEntered,
                scalarValue: charsEntered > 0 ? errorRate : nil,
                numerator: Double(block.incorrectCharacterCount),
                denominator: Double(charsEntered),
                betterDirection: .lowerIsBetter
            ),
            PracticeBlockMetricSnapshot(
                metricKey: "charsPerSecond",
                cohortKey: "overall",
                sampleCount: block.correctCharacterCount,
                scalarValue: charsPerSecond,
                numerator: Double(block.correctCharacterCount),
                denominator: elapsedSeconds,
                betterDirection: .higherIsBetter
            ),
            metric("recoveryLatencyMedianMs", cohort: "correctionEpisode", samples: episodeSummary.recoveryLatencies, direction: .lowerIsBetter),
            PracticeBlockMetricSnapshot(
                metricKey: "correctedErrorEpisodeCount",
                cohortKey: "overall",
                sampleCount: episodeSummary.corrected + episodeSummary.uncorrected,
                scalarValue: Double(episodeSummary.corrected),
                numerator: Double(episodeSummary.corrected),
                denominator: Double(episodeSummary.corrected + episodeSummary.uncorrected),
                betterDirection: .higherIsBetter
            )
        ].filter { $0.scalarValue != nil || $0.dispersionValue != nil || $0.sampleCount > 0 }
    }

    static func assessmentDescriptor(for block: PracticeRuntimeEngine.RuntimeBlockState) -> String {
        let promptLengths = block.prompts.map { $0.text.count }
        let averageLength = promptLengths.isEmpty ? 0 : promptLengths.reduce(0, +) / promptLengths.count
        let transitions = sampledTransitions(for: block)
        let sameHandCount = transitions.filter { $0.pattern == .sameHand }.count
        let crossHandCount = transitions.filter { $0.pattern == .crossHand }.count
        let farCount = transitions.filter { $0.distance == .far }.count
        let nearCount = transitions.filter { $0.distance == .near || $0.distance == .medium }.count
        return "family=\(block.weakness.recommendedDrill.rawValue); prompts=\(block.prompts.count); avgPromptLength=\(averageLength); sameHand=\(sameHandCount); crossHand=\(crossHandCount); near=\(nearCount); far=\(farCount)"
    }

    static func errorEpisodes(for block: PracticeRuntimeEngine.RuntimeBlockState) -> (corrected: Int, uncorrected: Int) {
        let summary = summarizeEpisodes(for: block)
        return (summary.corrected, summary.uncorrected)
    }

    private static func summarizeEpisodes(for block: PracticeRuntimeEngine.RuntimeBlockState) -> EpisodeSummary {
        var summary = EpisodeSummary()
        var episodeStart: Date?
        var sawBackspace = false

        for event in block.inputEvents {
            switch event.kind {
            case .character:
                guard let character = event.character else { continue }
                let promptCharacters = Array(event.promptText)
                guard event.promptIndexBeforeInput < promptCharacters.count else { continue }
                let expected = promptCharacters[event.promptIndexBeforeInput]
                let onCorrectPathBeforeInput = isPrefix(event.typedTextBeforeInput, of: event.promptText)
                if character != expected {
                    if episodeStart == nil {
                        episodeStart = event.timestamp
                    }
                    sawBackspace = false
                } else if let activeEpisodeStart = episodeStart,
                          sawBackspace,
                          onCorrectPathBeforeInput {
                    summary.recoveryLatencies.append(event.timestamp.timeIntervalSince(activeEpisodeStart) * 1_000)
                    summary.corrected += 1
                    sawBackspace = false
                    episodeStart = nil
                }
            case .backspace:
                if episodeStart != nil {
                    sawBackspace = true
                }
            }
        }

        if episodeStart != nil {
            summary.uncorrected += 1
        }

        summary.recoveryLatencies = summary.recoveryLatencies.filter { $0 >= 0 }
        return summary
    }

    private static func sampledTransitions(for block: PracticeRuntimeEngine.RuntimeBlockState) -> [SampledTransition] {
        var transitions: [SampledTransition] = []
        var previousCorrectCharacter: Character?
        var previousCorrectTimestamp: Date?

        for event in block.inputEvents {
            guard case .character = event.kind,
                  let character = event.character else { continue }
            let promptCharacters = Array(event.promptText)
            guard event.promptIndexBeforeInput < promptCharacters.count else { continue }
            let expected = promptCharacters[event.promptIndexBeforeInput]
            guard character == expected else { continue }

            if let previousCorrectCharacter,
               let previousCorrectTimestamp,
               let firstKeyCode = KeyGeometryMap.keyCode(for: previousCorrectCharacter),
               let secondKeyCode = KeyGeometryMap.keyCode(for: character) {
                let milliseconds = event.timestamp.timeIntervalSince(previousCorrectTimestamp) * 1_000
                if milliseconds >= 0, milliseconds <= 2_500 {
                    transitions.append(
                        SampledTransition(
                            milliseconds: milliseconds,
                            pattern: KeyGeometryMap.handPattern(from: firstKeyCode, to: secondKeyCode),
                            distance: KeyGeometryMap.distanceBucket(from: firstKeyCode, to: secondKeyCode)
                        )
                    )
                }
            }

            previousCorrectCharacter = character
            previousCorrectTimestamp = event.timestamp
        }

        return transitions
    }

    private static func metric(
        _ key: String,
        cohort: String,
        samples: [Double],
        useDispersion: Bool = false,
        direction: PracticeMetricDirection
    ) -> PracticeBlockMetricSnapshot {
        let sorted = samples.sorted()
        let scalarValue = useDispersion ? iqr(of: sorted) : median(of: sorted)
        return PracticeBlockMetricSnapshot(
            metricKey: key,
            cohortKey: cohort,
            sampleCount: samples.count,
            scalarValue: scalarValue,
            dispersionValue: useDispersion ? scalarValue : iqr(of: sorted),
            betterDirection: direction
        )
    }

    private static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }

    private static func iqr(of values: [Double]) -> Double? {
        guard values.count >= 4 else { return nil }
        let q1Index = Int(Double(values.count - 1) * 0.25)
        let q3Index = Int(Double(values.count - 1) * 0.75)
        return values[q3Index] - values[q1Index]
    }

    private static func isPrefix(_ typedText: String, of promptText: String) -> Bool {
        guard typedText.count <= promptText.count else { return false }
        return promptText.prefix(typedText.count) == typedText[typedText.startIndex..<typedText.endIndex]
    }
}
