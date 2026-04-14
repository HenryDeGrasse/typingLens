import Core
import Foundation

final class PracticeRuntimeEngine {
    private struct RuntimeBlockState {
        let block: PracticeBlock
        let prompts: [PracticePrompt]
        var currentPromptIndex: Int = 0
        var typedText: String = ""
        var remainingSeconds: Int
        var elapsedSeconds: Int = 0
        var completedPromptCount: Int = 0
        var correctCharacterCount: Int = 0
        var incorrectCharacterCount: Int = 0
        var backspaceCount: Int = 0

        var activePrompt: PracticePrompt? {
            guard !prompts.isEmpty else { return nil }
            return prompts[currentPromptIndex % prompts.count]
        }

        var upcomingPrompts: [PracticePrompt] {
            guard !prompts.isEmpty else { return [] }
            let count = min(3, prompts.count)
            return (0..<count).map { prompts[(currentPromptIndex + $0) % prompts.count] }
        }
    }

    private struct RuntimeSessionState {
        let plan: PracticeSessionPlan
        let laterTransferNote: String?
        var interactiveBlocks: [RuntimeBlockState]
        var activeBlockIndex: Int = 0
        var completedBlocks: [PracticeBlockResult] = []
        var status: PracticeRuntimeStatus = .running
        var note: String = "Type inside the focus pad. Prompt text stays transient and is never persisted."
    }

    private var session: RuntimeSessionState?

    var isActive: Bool {
        guard let session else { return false }
        return session.status == .running || session.status == .paused
    }

    func snapshot() -> PracticeRuntimeSnapshot {
        guard let session else {
            return PracticeRuntimeSnapshot()
        }

        let activeBlock = activeBlockState(in: session)

        return PracticeRuntimeSnapshot(
            status: session.status,
            sessionTitle: session.plan.primaryFocusTitle,
            rationale: session.plan.rationale,
            activeBlockIndex: activeBlock.map { _ in session.activeBlockIndex },
            interactiveBlockCount: session.interactiveBlocks.count,
            activeBlockTitle: activeBlock?.block.title,
            activeBlockKind: activeBlock?.block.kind,
            activeBlockFamily: resolvedFamily(for: activeBlock?.block, sessionPlan: session.plan),
            activeBlockDetail: activeBlock?.block.detail,
            remainingSeconds: activeBlock?.remainingSeconds ?? 0,
            elapsedSeconds: activeBlock?.elapsedSeconds ?? 0,
            activePrompt: activeBlock?.activePrompt,
            upcomingPrompts: activeBlock?.upcomingPrompts ?? [],
            typedText: activeBlock?.typedText ?? "",
            completedPromptCount: activeBlock?.completedPromptCount ?? 0,
            correctCharacterCount: activeBlock?.correctCharacterCount ?? 0,
            incorrectCharacterCount: activeBlock?.incorrectCharacterCount ?? 0,
            backspaceCount: activeBlock?.backspaceCount ?? 0,
            completedBlocks: session.completedBlocks,
            followUp: session.plan.followUp,
            laterTransferNote: session.laterTransferNote,
            note: session.note,
            requiresAppFocus: session.status == .running
        )
    }

    func start(plan: PracticeSessionPlan, weakness: WeaknessAssessment?) {
        let laterTransferNote = plan.blocks.first(where: { $0.kind == .transferCheck })?.detail
        let interactiveBlocks = plan.blocks
            .filter { $0.durationSeconds > 0 }
            .map { block in
                RuntimeBlockState(
                    block: block,
                    prompts: Self.prompts(for: block, weakness: weakness),
                    remainingSeconds: block.durationSeconds
                )
            }

        guard !interactiveBlocks.isEmpty else {
            session = RuntimeSessionState(
                plan: plan,
                laterTransferNote: laterTransferNote,
                interactiveBlocks: [],
                status: .completed,
                note: "This recommendation does not contain an interactive block yet."
            )
            return
        }

        session = RuntimeSessionState(
            plan: plan,
            laterTransferNote: laterTransferNote,
            interactiveBlocks: interactiveBlocks,
            status: .running,
            note: "Type inside the focus pad. Prompt text stays transient and is never persisted."
        )
    }

    func reset() {
        session = nil
    }

    func pause(reason: String? = nil) {
        guard var session, session.status == .running else { return }
        session.status = .paused
        session.note = reason ?? "Practice paused. Resume when you are ready."
        self.session = session
    }

    func resume() {
        guard var session, session.status == .paused else { return }
        session.status = .running
        session.note = "Practice resumed. Type inside the focus pad to continue."
        self.session = session
    }

    func cancel() {
        guard var session else { return }
        if activeBlockState(in: session) != nil {
            appendCurrentBlockResult(to: &session, noteSuffix: "Ended before the timer finished.")
        }
        session.status = .canceled
        session.note = "Practice session canceled. Prompt text was transient and was not saved."
        self.session = session
    }

    func tick() {
        guard var session, session.status == .running else { return }
        guard session.activeBlockIndex < session.interactiveBlocks.count else { return }

        session.interactiveBlocks[session.activeBlockIndex].elapsedSeconds += 1
        if session.interactiveBlocks[session.activeBlockIndex].remainingSeconds > 0 {
            session.interactiveBlocks[session.activeBlockIndex].remainingSeconds -= 1
        }

        let remainingSeconds = session.interactiveBlocks[session.activeBlockIndex].remainingSeconds
        if remainingSeconds <= 0 {
            appendCurrentBlockResult(to: &session)
            moveToNextBlockOrComplete(session: &session)
        }

        self.session = session
    }

    func advanceBlock() {
        guard var session else { return }
        guard activeBlockState(in: session) != nil else { return }
        appendCurrentBlockResult(to: &session, noteSuffix: "Advanced manually.")
        moveToNextBlockOrComplete(session: &session)
        self.session = session
    }

    func skipPrompt() {
        mutateActiveBlock { block in
            guard !block.prompts.isEmpty else { return }
            block.currentPromptIndex = (block.currentPromptIndex + 1) % block.prompts.count
            block.typedText = ""
        }
    }

    func handleCharacter(_ rawCharacter: String) {
        mutateActiveBlock { block in
            guard let normalizedCharacter = Self.normalizedCharacter(from: rawCharacter),
                  let activePrompt = block.activePrompt?.text.lowercased() else {
                return
            }

            let promptCharacters = Array(activePrompt)
            guard block.typedText.count < promptCharacters.count else { return }

            let nextIndex = block.typedText.count
            block.typedText.append(normalizedCharacter)

            if promptCharacters[nextIndex] == normalizedCharacter {
                block.correctCharacterCount += 1
            } else {
                block.incorrectCharacterCount += 1
            }

            if block.typedText == activePrompt {
                block.completedPromptCount += 1
                block.currentPromptIndex = (block.currentPromptIndex + 1) % max(block.prompts.count, 1)
                block.typedText = ""
            }
        }
    }

    func handleBackspace() {
        mutateActiveBlock { block in
            guard !block.typedText.isEmpty else { return }
            block.backspaceCount += 1
            block.typedText.removeLast()
        }
    }

    private func mutateActiveBlock(_ body: (inout RuntimeBlockState) -> Void) {
        guard var session, session.status == .running else { return }
        guard session.activeBlockIndex < session.interactiveBlocks.count else { return }
        body(&session.interactiveBlocks[session.activeBlockIndex])
        self.session = session
    }

    private func activeBlockState(in session: RuntimeSessionState) -> RuntimeBlockState? {
        guard session.activeBlockIndex < session.interactiveBlocks.count else {
            return nil
        }
        return session.interactiveBlocks[session.activeBlockIndex]
    }

    private func appendCurrentBlockResult(to session: inout RuntimeSessionState, noteSuffix: String? = nil) {
        guard session.activeBlockIndex < session.interactiveBlocks.count else { return }
        let block = session.interactiveBlocks[session.activeBlockIndex]
        let family = resolvedFamily(for: block.block, sessionPlan: session.plan)
        let baseNote = blockNote(for: block.block, family: family)
        let note = [baseNote, noteSuffix].compactMap { $0 }.joined(separator: " ")

        session.completedBlocks.append(
            PracticeBlockResult(
                title: block.block.title,
                kind: block.block.kind,
                drillFamily: family,
                elapsedSeconds: block.elapsedSeconds,
                completedPromptCount: block.completedPromptCount,
                correctCharacterCount: block.correctCharacterCount,
                incorrectCharacterCount: block.incorrectCharacterCount,
                backspaceCount: block.backspaceCount,
                note: note
            )
        )
    }

    private func moveToNextBlockOrComplete(session: inout RuntimeSessionState) {
        let nextIndex = session.activeBlockIndex + 1
        if nextIndex < session.interactiveBlocks.count {
            session.activeBlockIndex = nextIndex
            session.note = "Next block ready. Keep the pace smooth and accurate."
        } else {
            session.status = .completed
            session.activeBlockIndex = session.interactiveBlocks.count
            session.note = "Session complete. Check the summary and look for later passive transfer, not just immediate drill performance."
        }
    }

    private func resolvedFamily(for block: PracticeBlock?, sessionPlan: PracticeSessionPlan) -> PracticeDrillFamily? {
        guard let block else { return nil }
        if let drillFamily = block.drillFamily {
            return drillFamily
        }

        switch block.kind {
        case .confirmatoryProbe:
            return sessionPlan.blocks.first(where: { $0.kind == .drill })?.drillFamily
                ?? .mixedTransfer
        case .postCheck:
            return .mixedTransfer
        case .transferCheck:
            return .mixedTransfer
        case .drill:
            return block.drillFamily
        }
    }

    private func blockNote(for block: PracticeBlock, family: PracticeDrillFamily?) -> String {
        let familyNote = family.map { displayName(for: $0) } ?? "Focused probe"
        switch block.kind {
        case .confirmatoryProbe:
            return "Confirmatory probe using \(familyNote.lowercased())."
        case .drill:
            return "Drill block using \(familyNote.lowercased())."
        case .postCheck:
            return "Immediate post-check using mixed transfer material."
        case .transferCheck:
            return "Later transfer check."
        }
    }

    private func displayName(for family: PracticeDrillFamily) -> String {
        switch family {
        case .sameHandLadders:
            return "Same-Hand Ladders"
        case .reachAndReturn:
            return "Reach & Return"
        case .alternationRails:
            return "Alternation Rails"
        case .accuracyReset:
            return "Accuracy Reset"
        case .meteredFlow:
            return "Metered Flow"
        case .mixedTransfer:
            return "Mixed Transfer"
        }
    }

    private static func normalizedCharacter(from rawCharacter: String) -> Character? {
        let lowered = rawCharacter.lowercased()
        guard lowered.count == 1, let character = lowered.first else {
            return nil
        }

        if character == " " || character.isLetter {
            return character
        }

        return nil
    }

    private static func prompts(for block: PracticeBlock, weakness: WeaknessAssessment?) -> [PracticePrompt] {
        let cue: String = switch block.kind {
        case .confirmatoryProbe:
            "Medium pace. Confirm the pattern before chasing speed."
        case .drill:
            "Stay smooth. Prioritize clean reps over raw speed."
        case .postCheck:
            "Notice whether the pattern feels easier without extra corrections."
        case .transferCheck:
            "Later passive transfer check."
        }

        let family = resolvedFamily(for: block, weakness: weakness)
        let promptTexts: [String]
        switch family {
        case .sameHandLadders:
            promptTexts = promptsForSameHand(kind: block.kind)
        case .reachAndReturn:
            promptTexts = promptsForReach(kind: block.kind)
        case .alternationRails:
            promptTexts = promptsForAlternation(kind: block.kind)
        case .accuracyReset:
            promptTexts = promptsForAccuracy(kind: block.kind)
        case .meteredFlow:
            promptTexts = promptsForFlow(kind: block.kind)
        case .mixedTransfer:
            promptTexts = promptsForMixed(kind: block.kind)
        }

        return promptTexts.map { PracticePrompt(text: $0, cue: cue) }
    }

    private static func resolvedFamily(for block: PracticeBlock, weakness: WeaknessAssessment?) -> PracticeDrillFamily {
        if let drillFamily = block.drillFamily {
            return drillFamily
        }

        switch block.kind {
        case .confirmatoryProbe:
            return weakness?.recommendedDrill ?? .mixedTransfer
        case .postCheck:
            return .mixedTransfer
        case .transferCheck:
            return .mixedTransfer
        case .drill:
            return weakness?.recommendedDrill ?? .mixedTransfer
        }
    }

    private static func promptsForSameHand(kind: PracticeBlockKind) -> [String] {
        switch kind {
        case .confirmatoryProbe:
            return ["asdf fdsa", "sdfg gfds", "hjkl lkjh", "jklh hljk"]
        case .postCheck:
            return ["asdf fjfj", "hjkl dkdk", "sdfg slsl", "jklh thth"]
        case .transferCheck:
            return ["asdf fjfj"]
        case .drill:
            return [
                "asdf sdfg asdf",
                "sdfg gfds sdfg",
                "hjkl jklh hjkl",
                "jklh hljk jklh",
                "werw erwe werw",
                "uioi oiuo uioi"
            ]
        }
    }

    private static func promptsForReach(kind: PracticeBlockKind) -> [String] {
        switch kind {
        case .confirmatoryProbe:
            return ["aqa aza aqa", "frf tft frf", "olo plp olo", "iki uku iki"]
        case .postCheck:
            return ["aqa fjfj", "frf dkdk", "olo slsl", "iki thth"]
        case .transferCheck:
            return ["aqa frf olo"]
        case .drill:
            return [
                "aqa aza aqa",
                "qaq aza qaq",
                "frf tft frf",
                "olo plp olo",
                "iki uku iki",
                "aza qaq aza"
            ]
        }
    }

    private static func promptsForAlternation(kind: PracticeBlockKind) -> [String] {
        switch kind {
        case .confirmatoryProbe:
            return ["fjfj fjfj", "dkdk dkdk", "slsl slsl", "thth thth"]
        case .postCheck:
            return ["fjfj asdf", "dkdk qaqa", "slsl olo", "thth calm"]
        case .transferCheck:
            return ["fjfj dkdk slsl"]
        case .drill:
            return [
                "fjfj dkdk fjfj",
                "dkdk slsl dkdk",
                "slsl thth slsl",
                "thth fjfj thth",
                "fkfk djdj fkfk",
                "alal sksk alal"
            ]
        }
    }

    private static func promptsForAccuracy(kind: PracticeBlockKind) -> [String] {
        switch kind {
        case .confirmatoryProbe:
            return ["safe safe", "calm calm", "clean clean", "steady steady"]
        case .postCheck:
            return ["safe fjfj", "calm dkdk", "clean olo", "steady frf"]
        case .transferCheck:
            return ["safe calm steady"]
        case .drill:
            return [
                "safe safe safe",
                "calm hands calm",
                "clean reps clean",
                "steady focus steady",
                "soft reset soft",
                "easy pace easy"
            ]
        }
    }

    private static func promptsForFlow(kind: PracticeBlockKind) -> [String] {
        switch kind {
        case .confirmatoryProbe:
            return ["steady flow", "smooth reset", "easy pace", "soft rhythm"]
        case .postCheck:
            return ["steady fjfj", "smooth dkdk", "easy safe", "soft calm"]
        case .transferCheck:
            return ["steady flow easy pace"]
        case .drill:
            return [
                "steady flow steady flow",
                "smooth reset smooth reset",
                "easy pace easy pace",
                "soft rhythm soft rhythm",
                "clean restart clean restart",
                "calm return calm return"
            ]
        }
    }

    private static func promptsForMixed(kind: PracticeBlockKind) -> [String] {
        switch kind {
        case .confirmatoryProbe:
            return ["asdf fjfj", "aqa dkdk", "safe olo", "steady thth"]
        case .postCheck:
            return ["asdf fjfj aqa", "dkdk safe olo", "slsl calm frf", "hjkl thth steady"]
        case .transferCheck:
            return ["asdf fjfj aqa", "dkdk safe olo"]
        case .drill:
            return [
                "asdf fjfj aqa",
                "dkdk safe olo",
                "slsl calm frf",
                "hjkl thth steady",
                "safe aqa fjfj",
                "olo dkdk clean"
            ]
        }
    }
}
