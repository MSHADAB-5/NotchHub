import AppKit
import XCTest
@testable import NotchHub

final class ClipboardServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var pasteboard: NSPasteboard!
    private var service: ClipboardService!

    override func setUp() {
        super.setUp()
        suiteName = "NotchHubTests.Clipboard.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        pasteboard = NSPasteboard.withUniqueName()
        service = ClipboardService(defaults: defaults, pasteboard: pasteboard, startsMonitoring: false)
    }

    override func tearDown() {
        service = nil
        pasteboard.releaseGlobally()
        pasteboard = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLegacySavedItemsLoadWithoutAliases() throws {
        defaults.set(Data(#"[{"text":"FAKE-LEGACY-CONTENT"}]"#.utf8), forKey: "savedClipboardItems")
        let restored = ClipboardService(defaults: defaults, pasteboard: pasteboard, startsMonitoring: false)
        let item = try XCTUnwrap(restored.savedItems.first)
        XCTAssertEqual(item.text, "FAKE-LEGACY-CONTENT")
        XCTAssertNil(item.alias)
        XCTAssertEqual(item.displayTitle, item.preview)
    }

    func testRenamingPersistsWithoutChangingPayloadOrMetadata() throws {
        let original = ClipboardService.ClipboardItem(
            text: "FAKE-CONTENT-FOR-TESTING",
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .code,
            sourceAppName: "Test App"
        )
        let saved = service.saveItem(original)
        try service.renameSavedItem(id: saved.id, alias: "  PC_pass  ")
        let restored = ClipboardService(defaults: defaults, pasteboard: pasteboard, startsMonitoring: false)
        let renamed = try XCTUnwrap(restored.savedItems.first)
        XCTAssertEqual(renamed.alias, "PC_pass")
        XCTAssertEqual(renamed.displayTitle, "PC_pass")
        XCTAssertEqual(renamed.text, original.text)
        XCTAssertEqual(renamed.id, saved.id)
        XCTAssertEqual(renamed.timestamp, original.timestamp)
        XCTAssertEqual(renamed.kind, original.kind)
        XCTAssertEqual(renamed.sourceAppName, original.sourceAppName)
    }

    func testEmptyAliasRestoresContentPreview() throws {
        let saved = service.saveItem(makeItem())
        try service.renameSavedItem(id: saved.id, alias: "Saved name")
        try service.renameSavedItem(id: saved.id, alias: "   ")
        let renamed = try XCTUnwrap(service.savedItems.first)
        XCTAssertNil(renamed.alias)
        XCTAssertEqual(renamed.displayTitle, saved.preview)
    }

    func testAliasesRespectLengthAndCharacterValidation() throws {
        let saved = service.saveItem(makeItem())
        let allowed = String(repeating: "a", count: 64)
        try service.renameSavedItem(id: saved.id, alias: allowed)
        for invalid in [String(repeating: "a", count: 65), "two\nlines", "name\tvalue", "name\u{0000}", "name\u{007F}"] {
            XCTAssertThrowsError(try service.renameSavedItem(id: saved.id, alias: invalid))
            XCTAssertEqual(service.savedItems.first?.alias, allowed)
        }
        try service.renameSavedItem(id: saved.id, alias: "Office_PC-42")
        XCTAssertEqual(service.savedItems.first?.alias, "Office_PC-42")
    }

    func testRenamingMissingItemFailsWithoutChangingFavorites() {
        service.saveItem(makeItem())
        XCTAssertThrowsError(try service.renameSavedItem(id: UUID(), alias: "Missing"))
        XCTAssertEqual(service.savedItems.count, 1)
        XCTAssertNil(service.savedItems.first?.alias)
    }

    func testDuplicateContentKeepsExistingAliasAndSavedIdentity() throws {
        let saved = service.saveItem(makeItem())
        try service.renameSavedItem(id: saved.id, alias: "Reusable snippet")
        let duplicate = service.saveItem(makeItem())
        XCTAssertEqual(service.savedItems.count, 1)
        XCTAssertEqual(duplicate.id, saved.id)
        XCTAssertEqual(duplicate.alias, "Reusable snippet")
    }

    func testRenamingDoesNotReorderFavorites() throws {
        let first = service.saveItem(makeItem(text: "FAKE-FIRST"))
        let second = service.saveItem(makeItem(text: "FAKE-SECOND"))
        try service.renameSavedItem(id: first.id, alias: "First")
        XCTAssertEqual(service.savedItems.map(\.id), [second.id, first.id])
    }

    func testCopyingAliasWritesExactOriginalText() throws {
        let original = "\n FAKE-CLIPBOARD-CONTENT \n"
        let saved = service.saveItem(makeItem(text: original))
        try service.renameSavedItem(id: saved.id, alias: "PC_pass")
        service.copyToClipboard(try XCTUnwrap(service.savedItems.first))
        XCTAssertEqual(pasteboard.string(forType: .string), original)
        service.checkClipboard()
        XCTAssertTrue(service.history.isEmpty)
    }

    func testAllSupportedKindsCanBeNamedAndCopied() throws {
        for kind in [ClipboardService.ClipboardItem.ContentKind.text, .link, .code] {
            let original = ClipboardService.ClipboardItem(
                text: "FAKE-\(kind.rawValue)-CONTENT",
                timestamp: Date(),
                kind: kind
            )
            let saved = service.saveItem(original)
            try service.renameSavedItem(id: saved.id, alias: "Saved \(kind.label)")
            let renamed = try XCTUnwrap(service.savedItems.first)
            XCTAssertEqual(renamed.kind, kind)
            XCTAssertEqual(renamed.alias, "Saved \(kind.label)")
            service.copyToClipboard(renamed)
            XCTAssertEqual(pasteboard.string(forType: .string), original.text)
        }
    }

    func testSearchMatchesAliasOriginalContentAndMetadata() throws {
        let saved = service.saveItem(makeItem())
        try service.renameSavedItem(id: saved.id, alias: "PC_pass")
        let renamed = try XCTUnwrap(service.savedItems.first)
        XCTAssertTrue(renamed.matches(search: " pc_PASS "))
        XCTAssertTrue(renamed.matches(search: "FAKE-CONTENT"))
        XCTAssertTrue(renamed.matches(search: "Text"))
        XCTAssertTrue(renamed.matches(search: "  "))
        XCTAssertFalse(renamed.matches(search: "missing-label"))
    }

    func testClearRecentPreservesAliasedFavoritesAcrossReload() throws {
        pasteboard.setString("FAKE-RECENT", forType: .string)
        service.checkClipboard()
        XCTAssertEqual(service.history.count, 1)
        let saved = service.saveItem(try XCTUnwrap(service.history.first))
        try service.renameSavedItem(id: saved.id, alias: "Keep this")
        service.clearHistory()
        XCTAssertTrue(service.history.isEmpty)
        XCTAssertEqual(service.savedItems.first?.alias, "Keep this")
        let restored = ClipboardService(defaults: defaults, pasteboard: pasteboard, startsMonitoring: false)
        XCTAssertEqual(restored.savedItems.first?.alias, "Keep this")
    }

    func testAllFavoritesRemainAvailableBeyondEightItems() {
        for index in 0..<12 {
            service.saveItem(makeItem(text: "FAKE-ITEM-\(index)"))
        }
        XCTAssertEqual(service.savedItems.count, 12)
    }

    func testCaptureKeepsTwentyRecentItemsAndIgnoresRepeatedCopy() {
        for index in 0..<25 {
            pasteboard.clearContents()
            pasteboard.setString("FAKE-ITEM-\(index)", forType: .string)
            service.checkClipboard()
        }
        XCTAssertEqual(service.history.count, 20)
        XCTAssertEqual(service.history.first?.text, "FAKE-ITEM-24")
        pasteboard.clearContents()
        pasteboard.setString("FAKE-ITEM-24", forType: .string)
        service.checkClipboard()
        XCTAssertEqual(service.history.count, 20)
    }

    func testUnstarringRemovesOnlyTheSavedCopy() throws {
        pasteboard.setString("FAKE-RECENT", forType: .string)
        service.checkClipboard()
        let recent = try XCTUnwrap(service.history.first)
        let saved = service.saveItem(recent)
        try service.renameSavedItem(id: saved.id, alias: "Temporary")
        service.toggleSaved(recent)
        XCTAssertTrue(service.savedItems.isEmpty)
        XCTAssertEqual(service.history.first?.text, recent.text)
    }

    private func makeItem(text: String = "FAKE-CONTENT-FOR-TESTING") -> ClipboardService.ClipboardItem {
        ClipboardService.ClipboardItem(text: text, timestamp: Date())
    }
}
