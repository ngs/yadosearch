import Foundation

/// Who is staying.
///
/// Jalan counts a party in four kinds of preschooler, split by whether the child
/// is given bedding, a meal, both or neither, because that is what the room
/// charge depends on. The 2010 release exposed exactly these four rows and so
/// does this one — collapsing them would silently change the price the search
/// filters on.
public struct GuestParty: Sendable, Hashable, Codable {
    public var adults: Int
    /// 小学生 (`sc_num`).
    public var elementarySchoolChildren: Int
    /// 幼児：布団・食事ともにあり (`lc_num_bed_meal`).
    public var preschoolersWithBedAndMeal: Int
    /// 幼児：食事のみ (`lc_num_meal_only`).
    public var preschoolersWithMealOnly: Int
    /// 幼児：布団のみ (`lc_num_bed_only`).
    public var preschoolersWithBedOnly: Int
    /// 幼児：布団・食事ともになし (`lc_num_no_bed_meal`).
    public var preschoolersWithNeither: Int

    public init(
        adults: Int = 2,
        elementarySchoolChildren: Int = 0,
        preschoolersWithBedAndMeal: Int = 0,
        preschoolersWithMealOnly: Int = 0,
        preschoolersWithBedOnly: Int = 0,
        preschoolersWithNeither: Int = 0
    ) {
        self.adults = max(adults, 1)
        self.elementarySchoolChildren = max(elementarySchoolChildren, 0)
        self.preschoolersWithBedAndMeal = max(preschoolersWithBedAndMeal, 0)
        self.preschoolersWithMealOnly = max(preschoolersWithMealOnly, 0)
        self.preschoolersWithBedOnly = max(preschoolersWithBedOnly, 0)
        self.preschoolersWithNeither = max(preschoolersWithNeither, 0)
    }

    public var childCount: Int {
        elementarySchoolChildren
            + preschoolersWithBedAndMeal
            + preschoolersWithMealOnly
            + preschoolersWithBedOnly
            + preschoolersWithNeither
    }

    public var totalCount: Int { adults + childCount }
}
