//
//  MealTools.swift
//  LoopKit
//
//  CUSTOM (rdeboer180): absorption-pattern identifiers, favorites CSV
//  transfer, and recurring preset reminder schedules. Pure Foundation so the
//  workspace `tests/MealToolsChecks.swift` harness can compile it standalone.
//
//  Revert: delete this file and the pbxproj references; remove
//  `absorptionPatternIdentifier` from the carb/favorite types.
//

import Foundation

/// CUSTOM (rdeboer180): stable per-entry absorption-pattern identifier. This is
/// what `CarbEntry.resolvedAbsorptionModel(default:)` reads to pick the curve
/// for an entry, independently of its food text. Identifiers are persisted
/// (Core Data, HealthKit metadata, favorites, CSV), so never reuse or rename
/// a shipped value — add a new one.
public enum MealAbsorptionPattern {
    /// The global model from Settings (PiecewiseLinear in this fork).
    public static let standard = "standard-v1"
    /// 🥜 Delayed metabolic response — `DelayedMetabolicResponseAbsorption`.
    public static let delayedMetabolicV1 = "delayed-metabolic-v1"
    public static let supportedIdentifiers = [standard, delayedMetabolicV1]

    /// `nil` on an entry means "no explicit pattern": the legacy 🥜12h / 🌙12h /
    /// 🍲8h text markers still select their curves, otherwise the global model.
    public static func isSupported(_ identifier: String?) -> Bool {
        identifier == nil || supportedIdentifiers.contains(identifier!)
    }
}

/// CUSTOM (rdeboer180): human-readable timing for the 🥜 pattern, derived from
/// the same constants the dosing curve uses (`DelayedMetabolicResponseData` and
/// the curve's peak-rate segment), so the entry screen cannot describe a
/// different curve than the one Loop will run.
public struct DelayedMetabolicResponsePreview {
    public static let sampleCount = DelayedMetabolicResponseData.observedLateRiseMidpointHours.count
    public static let referenceDuration: TimeInterval = DelayedMetabolicResponseData.referenceDurationHours * 3600
    public static let observedMidpoints = DelayedMetabolicResponseData.observedLateRiseMidpointHours
    public static let averageFraction = DelayedMetabolicResponseData.averageFraction
    public static let observedFractionRange = DelayedMetabolicResponseData.earliestFraction...DelayedMetabolicResponseData.latestFraction

    public init() {}

    /// Mean observed late-rise midpoint, scaled to the selected duration.
    public func averageLateResponse(after duration: TimeInterval) -> TimeInterval {
        max(0, duration) * Self.averageFraction
    }

    /// Earliest…latest observed late-rise midpoint, scaled to the selected duration.
    public func observedTimingRange(after duration: TimeInterval) -> ClosedRange<TimeInterval> {
        let duration = max(0, duration)
        return (duration * Self.observedFractionRange.lowerBound)...(duration * Self.observedFractionRange.upperBound)
    }

    /// The curve's peak-rate window (the hours Loop models the fastest absorption), scaled to the selected duration.
    public func peakAbsorptionWindow(after duration: TimeInterval) -> ClosedRange<TimeInterval> {
        let duration = max(0, duration)
        let window = DelayedMetabolicResponseAbsorption.peakRateWindow
        return (duration * window.lowerBound)...(duration * window.upperBound)
    }
}

public struct FavoriteCSVRecord: Equatable {
    public var id: String
    public var name: String
    public var grams: Double
    public var foodType: String
    public var absorptionMinutes: Double
    public var patternIdentifier: String?

    public init(id: String, name: String, grams: Double, foodType: String,
                absorptionMinutes: Double, patternIdentifier: String?) {
        self.id = id; self.name = name; self.grams = grams; self.foodType = foodType
        self.absorptionMinutes = absorptionMinutes; self.patternIdentifier = patternIdentifier
    }
}

public enum FavoriteFoodCSV {
    public static let header = ["schema_version", "id", "name", "carbs_g", "food_type", "absorption_minutes", "absorption_pattern"]
    public static let maximumBytes = 2_000_000
    public static let maximumRecords = 1000

    public struct InvalidFile: LocalizedError {
        public let message: String
        public init(message: String) { self.message = message }
        public var errorDescription: String? { message }
    }

    public static func encode(_ records: [FavoriteCSVRecord]) -> String {
        let rows = [header] + records.map {
            ["1", $0.id, safeText($0.name), String($0.grams), safeText($0.foodType),
             String($0.absorptionMinutes), $0.patternIdentifier ?? ""]
        }
        return rows.map { $0.map(quote).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Text cells use a reversible leading apostrophe escape for spreadsheet formulas.
    private static func safeText(_ s: String) -> String {
        guard let first = s.first else { return s }
        return "'=+-@\t\r".contains(first) ? "'" + s : s
    }

    private static func decodeText(_ s: String) -> String {
        guard s.first == "'", let next = s.dropFirst().first, "'=+-@\t\r".contains(next) else { return s }
        return String(s.dropFirst())
    }

    private static func quote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    public static func decode(_ text: String, maximumGrams: Double = 350) throws -> [FavoriteCSVRecord] {
        guard text.utf8.count <= maximumBytes else { throw InvalidFile(message: "The CSV must be smaller than 2 MB.") }
        var text = text
        if text.first == "\u{FEFF}" { text.removeFirst() }
        let rows = try parse(text)
        guard rows.first == header else { throw InvalidFile(message: "Use the columns from a Loop favorites CSV export, in the same order.") }
        let body = rows.dropFirst().filter { !$0.allSatisfy(\.isEmpty) }
        guard !body.isEmpty, body.count <= maximumRecords else { throw InvalidFile(message: "Import between 1 and 1,000 favorites.") }
        var seen = Set<String>()
        return try body.enumerated().map { index, cells in
            let row = index + 2
            guard cells.count == header.count, cells[0] == "1" else { throw InvalidFile(message: "Row \(row) has an unsupported format or version.") }
            let id = cells[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let name = decodeText(cells[2]), type = decodeText(cells[4])
            guard !id.isEmpty, seen.insert(id).inserted else { throw InvalidFile(message: "Row \(row) has an empty or repeated ID.") }
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !type.isEmpty,
                  name.count <= 500, type.count <= 500 else { throw InvalidFile(message: "Row \(row) needs a name and food type of at most 500 characters.") }
            guard let grams = Double(cells[3]), grams.isFinite, grams > 0, grams <= maximumGrams else {
                throw InvalidFile(message: "Row \(row) needs a carb amount greater than zero and no more than \(Int(maximumGrams)) g.")
            }
            guard let minutes = Double(cells[5]), minutes.isFinite, (30...720).contains(minutes) else {
                throw InvalidFile(message: "Row \(row) needs an absorption time between 30 and 720 minutes.")
            }
            let pattern = cells[6].isEmpty ? nil : cells[6]
            guard MealAbsorptionPattern.isSupported(pattern) else {
                throw InvalidFile(message: "Row \(row) uses an absorption pattern this build cannot read.")
            }
            return FavoriteCSVRecord(id: id, name: name, grams: grams, foodType: type,
                                     absorptionMinutes: minutes, patternIdentifier: pattern)
        }
    }

    private static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], cell = ""
        var quoted = false, closed = false
        let chars = Array(text); var i = 0
        func endCell() { row.append(cell); cell = ""; closed = false }
        func endRow() { endCell(); rows.append(row); row = [] }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { cell.append(c); i += 1 }
                    else { quoted = false; closed = true }
                } else { cell.append(c) }
            } else if c == "," { endCell() }
            else if c == "\n" || c == "\r" || c == "\r\n" {
                endRow()
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
            } else if c == "\"", cell.isEmpty, !closed { quoted = true }
            else {
                guard !closed, c != "\"" else { throw InvalidFile(message: "The CSV contains an invalid quoted field.") }
                cell.append(c)
            }
            guard rows.count <= maximumRecords + 1 else { throw InvalidFile(message: "The CSV contains too many rows.") }
            i += 1
        }
        guard !quoted else { throw InvalidFile(message: "The CSV has an unfinished quoted field.") }
        if !cell.isEmpty || !row.isEmpty || closed { endRow() }
        return rows
    }
}

public struct RecurringPresetReminder: Codable, Equatable, Identifiable {
    public var id: UUID
    public var presetID: UUID
    public var weekdays: Set<Int>
    public var hour: Int
    public var minute: Int
    public var enabled: Bool

    public init(id: UUID = UUID(), presetID: UUID, weekdays: Set<Int>, hour: Int, minute: Int, enabled: Bool = true) {
        self.id = id; self.presetID = presetID; self.weekdays = weekdays
        self.hour = hour; self.minute = minute; self.enabled = enabled
    }

    public var isValid: Bool {
        !weekdays.isEmpty && weekdays.isSubset(of: Set(1...7)) && (0...23).contains(hour) && (0...59).contains(minute)
    }

    /// Calendar components intentionally omit timezone: reminders follow local time.
    public var calendarComponents: [DateComponents] {
        guard enabled, isValid else { return [] }
        return weekdays.sorted().map { day in
            var c = DateComponents(); c.weekday = day; c.hour = hour; c.minute = minute
            return c
        }
    }
}
