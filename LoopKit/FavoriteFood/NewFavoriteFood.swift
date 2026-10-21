//
//  NewFavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 8/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct NewFavoriteFood: FavoriteFood {
    public var name: String
    public var carbsQuantity: HKQuantity
    public var foodType: String
    public var absorptionPatternIdentifier: String?  // CUSTOM (rdeboer180): per-entry absorption pattern; revert by removing this field end-to-end
    public var absorptionTime: TimeInterval

    public init(name: String, carbsQuantity: HKQuantity, foodType: String, absorptionTime: TimeInterval, absorptionPatternIdentifier: String? = nil) {  // CUSTOM (rdeboer180): per-entry absorption pattern; revert by removing this field end-to-end
        self.name = name
        self.carbsQuantity = carbsQuantity
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.absorptionPatternIdentifier = absorptionPatternIdentifier  // CUSTOM (rdeboer180): per-entry absorption pattern; revert by removing this field end-to-end
    }
}
