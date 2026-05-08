//
//  CarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public protocol CarbEntry: SampleValue {
    var absorptionTime: TimeInterval? { get }

    // CUSTOM (rdeboer180): exposed on the protocol so per-entry absorption-model
    // selection (Delayed Second-Wave Dessert) can read the marker uniformly across
    // CarbEntry conformers (NewCarbEntry, StoredCarbEntry, CarbStatus). Stock
    // LoopKit confines foodType to concrete types only.
    // Revert: remove this requirement and the CarbStatus.foodType extension.
    var foodType: String? { get }
}

