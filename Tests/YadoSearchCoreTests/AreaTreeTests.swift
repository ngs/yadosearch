import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Area tree")
struct AreaTreeTests {
    private func tree() throws -> AreaTree {
        AreaTree(element: try XMLTree.parse(Fixture.data("area-tree")))
    }

    @Test("Covers the whole country")
    func coversTheCountry() throws {
        let tree = try tree()
        let prefectures = tree.regions.flatMap(\.prefectures)

        #expect(tree.regions.count == 12)
        #expect(prefectures.count == 47)
        #expect(tree.regions.first?.name == "北海道")
        #expect(prefectures.contains { $0.name == "沖縄県" })
    }

    @Test("Every level is coded")
    func everyLevelIsCoded() throws {
        for region in try tree().regions {
            #expect(!region.id.isEmpty)
            for prefecture in region.prefectures {
                #expect(prefecture.id.count == 6)
                for largeArea in prefecture.largeAreas {
                    #expect(largeArea.id.count == 6)
                    #expect(largeArea.smallAreas.allSatisfy { $0.id.count == 6 })
                }
            }
        }
    }

    @Test("Drills down to a small area")
    func drillsDown() throws {
        let tokyo = try #require(
            tree().regions
                .flatMap(\.prefectures)
                .first { $0.name == "東京都" }
        )

        #expect(tokyo.id == "130000")
        #expect(!tokyo.largeAreas.isEmpty)
        #expect(tokyo.largeAreas.contains { !$0.smallAreas.isEmpty })
    }

    @Test("A search narrows to the most specific code set")
    func narrowsToMostSpecificCode() {
        let selection = AreaSelection(regionID: "15", prefectureID: "130000", largeAreaID: "136700")

        #expect(selection.queryItem?.name == "l_area")
        #expect(selection.queryItem?.value == "136700")
        #expect(AreaSelection().queryItem == nil)
    }
}
