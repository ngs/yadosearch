import Foundation
import Testing
@testable import YadoSearchCore
import YadoSearchPlatform
@testable import YadoSearchUI

@Suite("Presentation")
@MainActor
struct PresentationTests {
    @Test("Distances read as metres below a kilometre and kilometres above")
    func formatsDistance() {
        #expect(Double(240).formattedDistance == "240m")
        #expect(Double(999).formattedDistance == "999m")
        #expect(Double(1_000).formattedDistance == "1.0km")
        #expect(Double(2_540).formattedDistance == "2.5km")
    }

    @Test("Every radius has a label, and it matches the measured distance")
    func labelsEveryRadius() {
        for radius in SearchRadius.allCases {
            #expect(!radius.label.isEmpty)
        }
        #expect(SearchRadius.aboutOneKilometre.label == "約1km")
        #expect(SearchRadius.aboutTenKilometres.label == "約10km")
        #expect(SearchRadius.aboutTenKilometres.approximateMetres == 10_000)
    }

    @Test("The area summary names the prefecture and the large area")
    func summarisesArea() {
        let full = AreaNames(region: "首都圏", prefecture: "東京都", large: "浅草", small: "浅草")
        let bare = AreaNames(region: nil, prefecture: nil, large: nil, small: nil)

        #expect(full.summary == "東京都・浅草")
        #expect(bare.summary == nil)
    }

    /// The service's own refusals carry the reason and the fix, so they must not
    /// be replaced with wording of our own.
    @Test("Service errors are shown verbatim")
    func passesServiceErrorsThrough() {
        let message = "宿名による宿の検索結果が200件を越えています。検索キーワードを変更してください。"

        #expect(searchErrorMessage(for: APIError.service(message: message)) == message)
        #expect(searchErrorMessage(for: APIError.service(message: "")).contains("応答"))
        // Nothing the user sees mentions the API key.
        for error: APIError in [.service(message: ""), .malformedResponse, .transport(description: "x")] {
            #expect(!searchErrorMessage(for: error).contains("APIキー"))
        }
    }

    @Test("Rates are shown in yen")
    func formatsRates() {
        #expect(Int(3_500).formattedYen.contains("3,500"))
    }

    @Test("Stay conditions cannot be set below one")
    func clampsStayConditions() {
        let stay = StayConditions(nights: 0, rooms: -3, party: GuestParty(adults: 0))

        #expect(stay.nights == 1)
        #expect(stay.rooms == 1)
        #expect(stay.party.adults == 1)
    }

    @Test("A party reads as a one-line summary")
    func summarisesTheParty() {
        #expect(GuestParty(adults: 2).summary == "大人2名")
        #expect(
            GuestParty(adults: 2, elementarySchoolChildren: 1, preschoolersWithBedOnly: 1).summary
                == "大人2名・子ども2名"
        )
    }

    @Test("Both stored lists are labelled")
    func labelsStoredLists() {
        for kind in StoredHotel.Kind.allCases {
            #expect(!kind.title.isEmpty)
            #expect(!kind.emptyTitle.isEmpty)
            #expect(!kind.emptyDescription.isEmpty)
            #expect(!kind.systemImage.isEmpty)
        }
    }

    @Test("A search mode has a title and a symbol")
    func describesSearchModes() {
        #expect(SearchMode.allCases.count == 4)
        for mode in SearchMode.allCases {
            #expect(!mode.title.isEmpty)
            #expect(!mode.systemImage.isEmpty)
        }
    }
}
