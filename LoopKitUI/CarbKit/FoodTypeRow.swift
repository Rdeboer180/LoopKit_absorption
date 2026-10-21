//
//  FoodTypeRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//
//  CUSTOM (rdeboer180): rewritten 2026-10. The row now holds three duration
//  quick-picks (🍭 2:30, 🌮 4:00, 🍲 6:00 — the fork's defaultAbsorptionTimes)
//  plus a 🍽️ button that opens the free-text/emoji food field. The former
//  🍲 8h and 🥜 12h quick-picks that wrote `🍲8h` / `🥜12h` text markers into
//  foodType are gone: the curve is now chosen by the separate Absorption
//  Pattern control (Loop's AbsorptionPatternRow → `absorptionPatternIdentifier`),
//  so renaming a food can no longer drop its curve. Legacy markers are still
//  honoured for old entries by CarbMath. Revert: restore the upstream file
//  (git show 4f374060:LoopKitUI/CarbKit/FoodTypeRow.swift) and the
//  FoodEmojiShortcut cases.
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
        VStack(alignment: .leading) {
            HStack {
                Text("Food Type")
                    .foregroundColor(.primary)
                Spacer()
                if usesCustomFoodType {
                    RowEmojiTextField(text: $foodType, isFocused: $isFocused, emojiType: .food,
                                      didSelectItemInSection: { _ in })
                }
                Button {
                    usesCustomFoodType = true
                    isFocused.toggle()
                } label: {
                    Text("🍽️").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit food description")
            }
            HStack {
                durationButton("🍭", title: "2:30", duration: defaultAbsorptionTimes.fast)
                durationButton("🌮", title: "4:00", duration: defaultAbsorptionTimes.medium)
                durationButton("🍲", title: "6:00", duration: defaultAbsorptionTimes.slow)
            }
        }
    }

    /// A quick-pick only sets the duration (and the default emoji used as the
    /// food text when no custom text is entered). It never touches the
    /// absorption pattern.
    private func durationButton(_ emoji: String, title: String, duration: TimeInterval) -> some View {
        let isSelected = abs(absorptionTime - duration) < 1
        return Button {
            absorptionTime = duration
            absorptionTimeWasEdited = true
            selectedDefaultAbsorptionTimeEmoji = emoji
        } label: {
            Text("\(emoji) \(title)")
                .font(.footnote)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Color.gray.opacity(0.15) : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Absorption duration, \(title) hours and minutes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
