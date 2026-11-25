//
//  DelayedMetabolicResponseAbsorption.swift
//  LoopKit
//
//  CUSTOM (rdeboer180): per-entry absorption curve for the 🥜 "delayed
//  metabolic response" pattern (late-evening high-fat desserts).
//
//  Revert: delete this file, the `delayedMetabolicV1` branch in
//  `CarbEntry.resolvedAbsorptionModel(default:)`, the pbxproj references, and
//  the `MealAbsorptionPattern.delayedMetabolicV1` identifier.
//

import Foundation

// MARK: - Source data

/// CUSTOM (rdeboer180): the measurements behind the 🥜 curve (v2, 2026-11-25),
/// kept next to the curve so the entry-screen preview and the dosing model can
/// never drift apart.
///
/// 23 dessert nights of 150 g or more (peanut butter and apple desserts,
/// 2026-08-21 to 2026-11-21), 11 run on the v1 curve and 12 before it. For
/// each 5-minute step: observed glucose change minus the modeled effect of the
/// insulin actually delivered (insulin counteraction), converted to grams with
/// ISF ÷ carb ratio; minus the clock-time median on carb-free stretches (Loop
/// COB < 1 g, nothing logged for 3 h); minus the expected remainder of that
/// evening's dinner. Each night's cumulative grams are divided by its own
/// 10-hour total and the median is taken across nights.
///
/// Source: research/dessert-recalibration-2026-11-25 (recalibrate.py,
/// results.json `pooledShape`, findings.md).
///
/// Replaces v1 (2026-10), which placed a late wave at ~50% of the duration
/// from the strongest 1–6 a.m. rise on six nights. That rise also happens on
/// carb-free nights, so it was not the dessert; the recalibration found no
/// dessert-specific late wave.
///
/// These are estimates under the insulin that was delivered, not measured
/// absorbed grams. Night-to-night spread is wide (middle half at 3 h: 38–54%).
public enum DelayedMetabolicResponseData {
    /// Selected absorption time on the measured nights.
    public static let referenceDurationHours: Double = 12

    /// Nights in the measurement.
    public static let nightCount = 23

    /// Median cumulative share absorbed at hours 1…10 after the first dessert entry.
    public static let measuredMedianByHour: [Double] = [0.125, 0.304, 0.461, 0.521, 0.652, 0.711, 0.828, 0.907, 0.956, 1.0]
}

// MARK: - Curve

/// CUSTOM (rdeboer180): 🥜 dessert cumulative-absorption curve (v2), in
/// percent of the entry's *selected* absorption time, so the shape scales with
/// whatever duration is chosen.
///
/// Knees at hour marks of a 12 h entry, smoothed through the measured medians
/// in `DelayedMetabolicResponseData` (largest gap 0.034, at 4 h):
///
///     0.000 → 0.00      0.583 →  0.83   (7 h)
///     0.083 → 0.12 (1h) 0.667 →  0.91   (8 h)
///     0.250 → 0.46 (3h) 0.833 →  0.98   (10 h)
///     0.417 → 0.65 (5h) 1.000 →  1.00   (12 h)
///
/// Fastest absorption 1–3 h after eating (rate 2.0× the mean), then a steady
/// decline. The small 10–12 h tail keeps a little carbs-on-board floor at the
/// end instead of none.
///
/// Front-loaded compared with v1 (13% by 3 h, 47% by 6 h at 12 h): Loop now
/// expects these carbs earlier, so its prediction rises sooner after the entry.
/// Loop's observed-absorption mechanism is unchanged.
///
/// NOT exposed as a global CarbAbsorptionModel option. Selected per entry by
/// `CarbEntry.resolvedAbsorptionModel(default:)` when
/// `absorptionPatternIdentifier == MealAbsorptionPattern.delayedMetabolicV1`.
/// The identifier keeps its v1 name so saved favorites and entries, and the
/// Nightscout marker, carry over.
struct DelayedMetabolicResponseAbsorption: CarbAbsorptionComputable {

    /// Knees as (percentTime, cumulativePercentAbsorbed). Both strictly increasing.
    static let knees: [(t: Double, p: Double)] = [
        (0.0,         0.00),
        (1.0 / 12.0,  0.12),   // 1 h at 12 h
        (3.0 / 12.0,  0.46),   // 3 h: end of the fastest segment
        (5.0 / 12.0,  0.65),   // 5 h
        (7.0 / 12.0,  0.83),   // 7 h
        (8.0 / 12.0,  0.91),   // 8 h
        (10.0 / 12.0, 0.98),   // 10 h
        (1.0,         1.00)    // 12 h
    ]

    /// Percent-time bounds of the fastest segment (for UI preview text).
    static var peakRateWindow: ClosedRange<Double> { (1.0 / 12.0)...(3.0 / 12.0) }

    public init() {}

    public func percentAbsorptionAtPercentTime(_ percentTime: Double) -> Double {
        if percentTime <= 0 { return 0 }
        if percentTime >= 1 { return 1 }
        let knees = Self.knees
        for i in 1..<knees.count {
            let curr = knees[i]
            if percentTime <= curr.t {
                let prev = knees[i - 1]
                let span = curr.t - prev.t
                guard span > 0 else { return prev.p }
                let frac = (percentTime - prev.t) / span
                return prev.p + frac * (curr.p - prev.p)
            }
        }
        return 1
    }

    public func percentTimeAtPercentAbsorption(_ percentAbsorption: Double) -> Double {
        if percentAbsorption <= 0 { return 0 }
        if percentAbsorption >= 1 { return 1 }
        let knees = Self.knees
        for i in 1..<knees.count {
            let curr = knees[i]
            if percentAbsorption <= curr.p {
                let prev = knees[i - 1]
                let span = curr.p - prev.p
                guard span > 0 else { return prev.t }
                let frac = (percentAbsorption - prev.p) / span
                return prev.t + frac * (curr.t - prev.t)
            }
        }
        return 1
    }

    public func percentRateAtPercentTime(_ percentTime: Double) -> Double {
        if percentTime <= 0 || percentTime >= 1 { return 0 }
        let knees = Self.knees
        for i in 1..<knees.count {
            let curr = knees[i]
            if percentTime < curr.t {
                let prev = knees[i - 1]
                let span = curr.t - prev.t
                guard span > 0 else { return 0 }
                return (curr.p - prev.p) / span
            }
        }
        return 0
    }
}
