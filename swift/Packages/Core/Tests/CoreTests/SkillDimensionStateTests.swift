import Testing
@testable import Core

@Suite("SkillDimensionState")
struct SkillDimensionStateTests {
    @Test func addingCombinesEachDimension() {
        let lhs = SkillDimensionState(control: 0.5, automaticity: 0.4, consistency: 0.3, stability: 0.2)
        let rhs = SkillDimensionState(control: 0.1, automaticity: 0.2, consistency: 0.3, stability: 0.4)
        let result = lhs.adding(rhs)
        #expect(abs(result.control - 0.6) < 0.0001)
        #expect(abs(result.automaticity - 0.6) < 0.0001)
        #expect(abs(result.consistency - 0.6) < 0.0001)
        #expect(abs(result.stability - 0.6) < 0.0001)
    }

    @Test func clampedKeepsValuesInsideUnitInterval() {
        let raw = SkillDimensionState(control: 1.5, automaticity: -0.3, consistency: 0.7, stability: 99)
        let clamped = raw.clamped()
        #expect(clamped.control == 1.0)
        #expect(clamped.automaticity == 0.0)
        #expect(clamped.consistency == 0.7)
        #expect(clamped.stability == 1.0)
    }

    @Test func clampedAcceptsCustomRange() {
        let raw = SkillDimensionState(control: 5, automaticity: -2, consistency: 0, stability: 0)
        let clamped = raw.clamped(to: -1...3)
        #expect(clamped.control == 3)
        #expect(clamped.automaticity == -1)
    }
}
