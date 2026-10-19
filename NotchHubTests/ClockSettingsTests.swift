import XCTest
@testable import NotchHub

final class ClockSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "NotchHubTests.ClockSettings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsPreserveLocalAndParisClocks() {
        let settings = SettingsService(defaults: defaults)
        XCTAssertEqual(settings.primaryClockTimeZoneIdentifier, ClockTimeZone.followMacIdentifier)
        XCTAssertEqual(settings.referenceClockTimeZoneIdentifier, "Europe/Paris")
        XCTAssertEqual(settings.primaryClockTimeZone.identifier, TimeZone.current.identifier)
        XCTAssertEqual(settings.referenceClockTimeZone.identifier, "Europe/Paris")
    }

    func testBothLocationsPersistIndependently() {
        let settings = SettingsService(defaults: defaults)
        settings.primaryClockTimeZoneIdentifier = "Asia/Kolkata"
        settings.referenceClockTimeZoneIdentifier = "America/New_York"

        let restored = SettingsService(defaults: defaults)
        XCTAssertEqual(restored.primaryClockTimeZone.identifier, "Asia/Kolkata")
        XCTAssertEqual(restored.referenceClockTimeZone.identifier, "America/New_York")
    }

    func testExistingReferenceSelectionSurvivesUpgrade() {
        defaults.set("Asia/Tokyo", forKey: "referenceClockTimeZoneIdentifier")
        let settings = SettingsService(defaults: defaults)
        XCTAssertEqual(settings.referenceClockTimeZoneIdentifier, "Asia/Tokyo")
        XCTAssertEqual(settings.primaryClockTimeZoneIdentifier, ClockTimeZone.followMacIdentifier)
    }

    func testInvalidStoredLocationsFallBackSafely() {
        defaults.set("Invalid/Primary", forKey: "primaryClockTimeZoneIdentifier")
        defaults.set("Invalid/Reference", forKey: "referenceClockTimeZoneIdentifier")
        let settings = SettingsService(defaults: defaults)
        XCTAssertEqual(settings.primaryClockTimeZoneIdentifier, ClockTimeZone.followMacIdentifier)
        XCTAssertEqual(settings.referenceClockTimeZoneIdentifier, "Europe/Paris")
    }

    func testInvalidRuntimeLocationsStillResolveSafely() {
        let settings = SettingsService(defaults: defaults)
        settings.primaryClockTimeZoneIdentifier = "Invalid/Primary"
        settings.referenceClockTimeZoneIdentifier = "Invalid/Reference"
        XCTAssertEqual(settings.primaryClockTimeZone.identifier, TimeZone.current.identifier)
        XCTAssertEqual(settings.referenceClockTimeZone.identifier, "Europe/Paris")
    }

    func testEitherClockCanFollowMac() {
        let settings = SettingsService(defaults: defaults)
        settings.referenceClockTimeZoneIdentifier = ClockTimeZone.followMacIdentifier
        XCTAssertEqual(settings.referenceClockTimeZone.identifier, TimeZone.current.identifier)
    }

    func testCatalogIsUniqueAndSearchesCitiesAndIdentifiers() {
        let options = ClockTimeZone.options(matching: "")
        XCTAssertEqual(Set(options.map(\.identifier)).count, options.count)
        XCTAssertTrue(options.contains { $0.identifier == "UTC" })
        XCTAssertTrue(ClockTimeZone.options(matching: " new york ").contains {
            $0.identifier == "America/New_York"
        })
        XCTAssertTrue(ClockTimeZone.options(matching: "Asia/Kolkata").contains {
            $0.identifier == "Asia/Kolkata"
        })
        XCTAssertTrue(ClockTimeZone.options(matching: "not-a-real-location").isEmpty)
    }

    func testPlaceLabelsUseReadableCities() throws {
        XCTAssertEqual(ClockTimeZone.placeName(for: try XCTUnwrap(TimeZone(identifier: "America/New_York"))), "New York")
        XCTAssertEqual(ClockTimeZone.placeName(for: try XCTUnwrap(TimeZone(identifier: "UTC"))), "UTC")
    }

    func testOffsetsHandleDaylightSavingAndFractionalHours() throws {
        let winter = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let summer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        XCTAssertEqual(ClockTimeZone.utcOffsetString(for: newYork, at: winter), "UTC -5")
        XCTAssertEqual(ClockTimeZone.utcOffsetString(for: newYork, at: summer), "UTC -4")
        XCTAssertEqual(
            ClockTimeZone.utcOffsetString(for: try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata")), at: winter),
            "UTC +5:30"
        )
        XCTAssertEqual(
            ClockTimeZone.utcOffsetString(for: try XCTUnwrap(TimeZone(identifier: "Asia/Kathmandu")), at: winter),
            "UTC +5:45"
        )
        XCTAssertEqual(
            ClockTimeZone.utcOffsetString(for: try XCTUnwrap(TimeZone(identifier: "UTC")), at: winter),
            "UTC"
        )
    }

    func testSelectedZonesHaveIndependentCalendarDates() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-01T23:30:00Z"))
        let settings = SettingsService(defaults: defaults)
        settings.primaryClockTimeZoneIdentifier = "Asia/Tokyo"
        settings.referenceClockTimeZoneIdentifier = "America/Los_Angeles"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.primaryClockTimeZone
        XCTAssertEqual(calendar.component(.day, from: date), 2)
        calendar.timeZone = settings.referenceClockTimeZone
        XCTAssertEqual(calendar.component(.day, from: date), 1)
    }
}
