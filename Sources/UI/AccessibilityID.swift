import Foundation

/// The handful of elements the App Store screenshot run has to find.
///
/// The interface is Japanese and English, so a capture test cannot look for
/// "宿をさがす" — it would find nothing on the English pass. These identifiers
/// are what it navigates by instead, and they are the only reason they exist:
/// nothing in the app reads them.
public enum YadoAccessibilityID {
    /// The name field on the search form.
    public static let searchKeyword = "search.keyword"
    /// The row that opens the 検索先 sheet, and a site's row inside it.
    public static let searchScope = "search.scope"
    public static func searchScope(_ provider: String) -> String { "search.scope.\(provider)" }
    /// The button that runs the search.
    public static let searchSubmit = "search.submit"
    /// A row in the results list, by position.
    public static func hotelRow(_ index: Int) -> String { "hotel.row.\(index)" }
    /// One segment of the じゃらん / 楽天トラベル picker on the detail screen, by
    /// the provider's raw value. The screenshots are taken on じゃらん, which
    /// quotes guide prices without a date; 楽天 has no undated mode and asks
    /// for one instead — a correct screen and a dull photograph.
    public static func hotelProvider(_ provider: String) -> String { "hotel.provider.\(provider)" }
    /// The booking button in the detail screen's toolbar.
    public static let hotelBooking = "hotel.booking"
    /// The heart in the detail screen's toolbar.
    public static let hotelFavorite = "hotel.favorite"
    /// The plan list on the detail screen, which is what "scrolled far enough"
    /// means there.
    public static let hotelPlans = "hotel.plans"
}
