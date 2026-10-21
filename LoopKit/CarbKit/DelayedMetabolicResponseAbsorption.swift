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

/// CUSTOM (rdeboer180): the observations behind the delayed pattern, kept next
/// to the curve so the entry-screen preview and the dosing model can never
/// drift apart.
///
/// Six repeated evenings (2026-08-29, 09-11, 09-18, 10-02, 10-09, 10-16): a
/// 2½ h zoodle dinner, no other carbs logged between dessert and 6 a.m., and
/// 🥜 dessert entries logged at 12 h. For each night the strongest one-hour
/// CGM rise between 1 and 6 a.m. was located; each value is the midpoint of
/// that hour, in hours after the first dessert entry.
///
/// Source: research/meal-timing-2026-10-20/stacked-meals-results.json
/// (`episodes[].strongest_one_hour_rise_between_1_and_6am`).
///
/// These are glucose observations under the insulin that was actually
/// delivered, not measured absorbed grams. They locate *when* the late wave
/// tends to happen; they do not establish what share of the carbs it carries.
public enum DelayedMetabolicResponseData {
    /// Selected absorption time on every one of the six nights.
    public static let referenceDurationHours: Double = 12

    /// Midpoint of the strongest overnight one-hour rise, hours after the first dessert entry.
    public static let observedLateRiseMidpointHours: [Double] = [6.12, 5.84, 4.31, 4.56, 7.61, 7.66]

    /// Mean midpoint as a fraction of the selected duration: 6.02 h / 12 h ≈ 0.501.
    public static var averageFraction: Double {
        observedLateRiseMidpointHours.reduce(0, +) / Double(observedLateRiseMidpointHours.count) / referenceDurationHours
    }

    /// Earliest observed midpoint as a fraction of duration: 4.31 h / 12 h ≈ 0.359.
    public static var earliestFraction: Double { observedLateRiseMidpointHours.min()! / referenceDurationHours }

    /// Latest observed midpoint as a fraction of duration: 7.66 h / 12 h ≈ 0.638.
    public static var latestFraction: Double { observedLateRiseMidpointHours.max()! / referenceDurationHours }
}

// MARK: - Curve

/// CUSTOM (rdeboer180): delayed-wave cumulative-absorption curve, expressed in
/// percent of the entry's *selected* absorption time so the same shape applies
/// whatever duration is chosen (the user's requirement: "regardless of the
/// absorption time set, the aggressive phase lands at the observed fraction").
///
/// Knee placement, all derived from `DelayedMetabolicResponseData`:
///
/// * 0.36 and 0.64 — the earliest and latest observed late-rise midpoints
///   (0.359 / 0.638) bound the high-rate wave.
/// * 0.43–0.57 — the peak-rate segment, centred on the 0.50 average
///   (0.501) with a ±0.07 half-width (half the observed spread).
/// * Before 0.36 the rate ramps slowly (fat-delayed early phase); after 0.64 a
///   steady tail finishes the entry by 1.0.
///
/// Cumulative percent absorbed at each knee (sums to 100%):
///
///     0.000 → 0.00      0.430 → 0.33
///     0.125 → 0.05      0.570 → 0.60   (peak segment, rate 1.93× mean)
///     0.250 → 0.13      0.640 → 0.70
///     0.360 → 0.23      0.800 → 0.86
///                       1.000 → 1.00
///
/// At a 12 h entry that is: 5% by 1.5 h, 13% by 3 h, 23% by 4.3 h, 60% by
/// 6.8 h, 86% by 9.6 h; the peak-rate window runs 5.2–6.8 h after eating.
///
/// The early/late *share* (23% before the wave, 47% inside it, 30% after) is
/// a design choice consistent with the earlier 🥜12h dessert curve, not a
/// measured value — the six nights only locate the timing.
///
/// Compared with the fork's global PiecewiseLinear model (26% absorbed by
/// 25% time, 63% by 50%), this curve holds more carbs back for later, so Loop
/// keeps a larger minimum carbs-on-board floor while observed absorption is
/// quiet. Loop's observed-absorption mechanism is unchanged: a strong early
/// counteraction effect still consumes the entry early, whichever curve is
/// selected.
///
/// NOT exposed as a global CarbAbsorptionModel option. Selected per entry by
/// `CarbEntry.resolvedAbsorptionModel(default:)` when
/// `absorptionPatternIdentifier == MealAbsorptionPattern.delayedMetabolicV1`.
struct DelayedMetabolicResponseAbsorption: CarbAbsorptionComputable {

    /// Knees as (percentTime, cumulativePercentAbsorbed). Both strictly increasing.
    static let knees: [(t: Double, p: Double)] = [
        (0.000, 0.00),
        (0.125, 0.05),
        (0.250, 0.13),
        (0.360, 0.23),   // wave onset  = earliest observed midpoint (0.359)
        (0.430, 0.33),
        (0.570, 0.60),   // peak-rate segment centred on the 0.50 average
        (0.640, 0.70),   // wave end    = latest observed midpoint (0.638)
        (0.800, 0.86),
        (1.000, 1.00)
    ]

    /// Percent-time bounds of the peak-rate segment (for UI preview text).
    static var peakRateWindow: ClosedRange<Double> { 0.430...0.570 }

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
