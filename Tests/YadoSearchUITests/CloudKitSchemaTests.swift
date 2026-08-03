import Foundation
import SwiftData
import Testing
@testable import YadoSearchPlatform

/// SwiftData's CloudKit mirroring rejects a schema at container creation, not at
/// compile time — a crash on first launch rather than a build error. These pin
/// the rules so a property added without a default is caught here instead.
@Suite("CloudKit schema requirements")
@MainActor
struct CloudKitSchemaTests {
    private var entities: [Schema.Entity] {
        YadoSearchModelContainer.schema.entities
    }

    @Test("Both stored types are in the schema")
    func schemaCoversBothTypes() {
        let names = Set(entities.map(\.name))

        #expect(names.contains("StoredHotel"))
        #expect(names.contains("StoredSearch"))
    }

    /// Every property must be optional or carry a default, because mirroring has
    /// to be able to materialise a record from a partial remote change.
    @Test("Every property is optional or defaulted")
    func everyPropertyIsOptionalOrDefaulted() {
        for entity in entities {
            for property in entity.properties {
                guard let attribute = property as? Schema.Attribute else { continue }
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name).\(attribute.name) is neither optional nor defaulted"
                )
            }
        }
    }

    /// `@Attribute(.unique)` is not allowed. The stores look an identifier up
    /// before inserting instead.
    @Test("No unique constraints")
    func noUniqueAttributes() {
        for entity in entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name) declares a uniqueness constraint")
        }
    }

    /// The rules only matter if the app actually asks to mirror.
    @Test("The container identifier is the app's")
    func namesTheContainer() {
        #expect(YadoSearchCloudKit.containerIdentifier == "iCloud.org.ngsdev.iphone.Yado")
    }

    /// Without the entitlement — every simulator and CI build — the ladder has to
    /// come down to something that opens.
    @Test("A container is produced even when CloudKit is unavailable")
    func fallsBackWhenSyncIsUnavailable() {
        let container = YadoSearchModelContainer.make(inMemory: true)

        #expect(container.schema.entities.count == entities.count)
    }

    /// `ModelContainer` accepts a CloudKit configuration it cannot honour and
    /// then traps asynchronously inside CloudKit, which no `try?` can catch. The
    /// gate is what prevents that, so a test process must never pass it.
    @Test("Mirroring is off in a test process")
    func doesNotMirrorUnderTest() {
        #expect(!YadoSearchCloudKit.isAvailable)
    }
}
