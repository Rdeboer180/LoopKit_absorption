//
//  FoodTypeRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//
//  CUSTOM (rdeboer180), 2026-10-23: back to the upstream look — duration
//  presets sit inline next to the 🍽️ plate, no time labels:
//  🍭 fast (2:30) · 🌮 medium (4:00) · 🍲 slow (6:00) · 🍽️ custom text.
//  Differences from upstream: 🍲 replaces 🍕; the highlighted preset follows
//  the entry's actual absorption time instead of a stored index; presets set
//  only the duration (never the food text or the absorption pattern, which
//  Loop's separate Standard / 🥜 Delayed control owns). The former 🍲8h and
//  🥜12h marker-writing quick-picks stay removed; CarbMath still honours
//  those legacy markers on old entries.
//  Revert: restore `git show 4f374060:LoopKitUI/CarbKit/FoodTypeRow.swift`.
//

import SwiftUI
import LoopKit

public struct FoodTypeRow: View {
    @Binding private var foodType: String
    @Binding private var absorptionTime: TimeInterval
    @Binding private var selectedDefaultAbsorptionTimeEmoji: String
    @Binding private var usesCustomFoodType: Bool
    @Binding private var absorptionTimeWasEdited: Bool
    @Binding private var isFocused: Bool

    private let defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes

    private struct Preset {
        let emoji: String
        let label: String
        let duration: TimeInterval
    }

    private var presets: [Preset] {
        [
            Preset(emoji: "🍭", label: "Fast", duration: defaultAbsorptionTimes.fast),
            Preset(emoji: "🌮", label: "Medium", duration: defaultAbsorptionTimes.medium),
            Preset(emoji: "🍲", label: "Slow", duration: defaultAbsorptionTimes.slow),
        ]
    }

    /// Contains emoji shortcuts, an emoji keyboard, and modifies absorption time to match emoji
    public init(foodType: Binding<String>, absorptionTime: Binding<TimeInterval>, selectedDefaultAbsorptionTimeEmoji: Binding<String>, usesCustomFoodType: Binding<Bool>, absorptionTimeWasEdited: Binding<Bool>, isFocused: Binding<Bool>, defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes) {
        self._foodType = foodType
        self._absorptionTime = absorptionTime
        self._selectedDefaultAbsorptionTimeEmoji = selectedDefaultAbsorptionTimeEmoji
        self._usesCustomFoodType = usesCustomFoodType
        self._absorptionTimeWasEdited = absorptionTimeWasEdited
        self._isFocused = isFocused
        self.defaultAbsorptionTimes = defaultAbsorptionTimes
    }

    public var body: some View {
        HStack {
            Text("Food Type")
                .foregroundColor(.primary)

            Spacer()

            if usesCustomFoodType {
                RowEmojiTextField(text: $foodType, isFocused: $isFocused, emojiType: .food, didSelectItemInSection: didSelectEmojiInSection)
                    .onTapGesture {
                        // so that row does not lose focus on cursor move
                        if !isFocused {
                            rowTapped()
                        }
                    }
            }
            else {
                HStack(spacing: 5) {
                    ForEach(presets, id: \.emoji) { preset in
                        let isSelected = abs(absorptionTime - preset.duration) < 1
                        Text(preset.emoji)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(isSelected ? Color.gray.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDefaultAbsorptionTimeEmoji = preset.emoji
                                absorptionTime = preset.duration
                            }
                            .accessibilityElement()
                            .accessibilityLabel("\(preset.label) absorption, \(durationText(preset.duration))")
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }

                    Text("🍽️")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                        .onTapGesture { rowTapped() }
                        .accessibilityElement()
                        .accessibilityLabel("Describe food")
                        .accessibilityAddTraits(.isButton)
                }
                .onAppear {
                    // Keep the saved food text in step with the highlighted preset.
                    if let match = presets.first(where: { abs(absorptionTime - $0.duration) < 1 }) {
                        selectedDefaultAbsorptionTimeEmoji = match.emoji
                    }
                }
            }
        }
        .frame(height: 44)
        .padding(.vertical, -8)
        .onTapGesture {
            rowTapped()
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = Int((duration / 60).rounded())
        return minutes % 60 == 0 ? "\(minutes / 60) hours" : "\(minutes / 60) hours \(minutes % 60) minutes"
    }

    private func didSelectEmojiInSection(_ section: Int) {
        // only adjust if it wasn't already edited, food selected was not in other category
        guard !absorptionTimeWasEdited, section < presets.count else {
            return
        }

        absorptionTime = presets[section].duration
    }

    private func rowTapped() {
        withAnimation {
            if !isFocused {
                usesCustomFoodType = true
            }
            isFocused.toggle()
        }
    }
}
