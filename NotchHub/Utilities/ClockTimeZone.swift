import Foundation

enum ClockTimeZone {
    static let followMacIdentifier = "system"
    static let defaultReferenceIdentifier = "Europe/Paris"

    struct Option: Identifiable {
        let identifier: String
        let label: String
        var id: String { identifier }
    }

    private static let catalog: [Option] = {
        Set(TimeZone.knownTimeZoneIdentifiers + ["UTC", "Asia/Kolkata", "Asia/Kathmandu", "Europe/Kyiv"])
            .compactMap { identifier -> Option? in
                guard let zone = TimeZone(identifier: identifier) else { return nil }
                let region = identifier.split(separator: "/").dropLast()
                    .joined(separator: " / ").replacingOccurrences(of: "_", with: " ")
                let city = placeName(for: zone)
                return Option(identifier: identifier, label: region.isEmpty ? city : "\(city) · \(region)")
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }()

    static func options(matching search: String) -> [Option] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog }
        return catalog.filter {
            $0.label.localizedCaseInsensitiveContains(query) ||
                $0.identifier.localizedCaseInsensitiveContains(query)
        }
    }

    static func validatedIdentifier(_ identifier: String?, fallback: String) -> String {
        guard let identifier,
              identifier == followMacIdentifier || TimeZone(identifier: identifier) != nil else {
            return fallback
        }
        return identifier
    }

    static func resolve(_ identifier: String, fallback: String = followMacIdentifier) -> TimeZone {
        let valid = validatedIdentifier(identifier, fallback: fallback)
        if valid == followMacIdentifier { return .autoupdatingCurrent }
        return TimeZone(identifier: valid) ?? .autoupdatingCurrent
    }

    static func placeName(for timeZone: TimeZone) -> String {
        if ["UTC", "GMT", "Etc/UTC", "Etc/GMT"].contains(timeZone.identifier) { return "UTC" }
        return timeZone.identifier.split(separator: "/").last
            .map { $0.replacingOccurrences(of: "_", with: " ") } ?? timeZone.identifier
    }

    static func utcOffsetString(for timeZone: TimeZone, at date: Date) -> String {
        let totalMinutes = timeZone.secondsFromGMT(for: date) / 60
        guard totalMinutes != 0 else { return "UTC" }
        let sign = totalMinutes > 0 ? "+" : "-"
        let hours = abs(totalMinutes) / 60
        let minutes = abs(totalMinutes) % 60
        let suffix = minutes == 0 ? "" : String(format: ":%02d", minutes)
        return "UTC \(sign)\(hours)\(suffix)"
    }
}
