import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Plan search response")
struct PlanParsingTests {
    private func plans() throws -> [Plan] {
        try XMLTree.parse(Fixture.data("plan-search"))
            .children(named: "Plan")
            .compactMap(Plan.init(element:))
    }

    @Test("Decodes a plan and the inn it belongs to")
    func decodesAPlan() throws {
        let plan = try #require(plans().first)

        #expect(!plan.name.isEmpty)
        #expect(!plan.id.planCode.isEmpty)
        #expect(plan.hotel.id == "300002")
        #expect(plan.sampleRate ?? 0 > 0)
        #expect(plan.rateType != nil)
        #expect(plan.detailURL != nil)
    }

    /// The same `PlanCD` comes back once per room type, so the plan code alone
    /// would collide in a `List`.
    @Test("Identity includes the room code")
    func identityIncludesRoomCode() throws {
        let plans = try plans()

        #expect(Set(plans.map(\.id)).count == plans.count)
        #expect(plans.allSatisfy { $0.id.roomCode != nil })
    }

    @Test("Room facilities are listed")
    func decodesFacilities() throws {
        let plan = try #require(plans().first)

        #expect(!plan.facilities.isEmpty)
        #expect(plan.facilities.allSatisfy { !$0.isEmpty })
    }

    @Test("A plan without an inn is dropped")
    func dropsPlanWithoutHotel() {
        let element = XMLTreeNode(
            name: "Plan",
            children: [
                XMLTreeNode(name: "PlanCD", text: "123"),
                XMLTreeNode(name: "PlanName", text: "素泊まり")
            ]
        )

        #expect(Plan(element: element) == nil)
    }
}
