//
//  SyncCarbObject.swift
//  LoopKit
//
//  Created by Darin Krauss on 8/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum Operation: Int, CaseIterable, Codable {
    case create
    case update
    case delete
}

public struct SyncCarbObject: Codable, Equatable {
    public let absorptionTime: TimeInterval?
    public let createdByCurrentApp: Bool
    public let foodType: String?
    public let absorptionPatternIdentifier: String?  // CUSTOM (rdeboer180): per-entry absorption pattern; revert by removing this field end-to-end
    public let grams: Double
    public let startDate: Date
    public let uuid: UUID?
    public let provenanceIdentifier: String
    public let syncIdentifier: String?
    public let syncVersion: Int?
    public let userCreatedDate: Date?
    public let userUpdatedDate: Date?
    public let userDeletedDate: Date?
    public let operation: Operation
    public let addedDate: Date?
    public let supercededDate: Date?

    public init(absorptionTime: TimeInterval?,
                createdByCurrentApp: Bool,
                foodType: String?,
                grams: Double,
                startDate: Date,
                uuid: UUID?,
                provenanceIdentifier: String,
                syncIdentifier: String?,
                syncVersion: Int?,
                userCreatedDate: Date?,
                userUpdatedDate: Date?,
                userDeletedDate: Date?,
                operation: Operation,
                addedDate: Date?,
                supercededDate: Date?,
                absorptionPatternIdentifier: String? = nil) {  // CUSTOM (rdeboer180): per-entry absorption pattern; revert by removing this field end-to-end
        self.absorptionTime = absorptionTime
        self.createdByCurrentApp = createdByCurrentApp
        self.foodType = foodType
        self.absorptionPatternIdentifier = absorptionPatternIdentifier  // CUSTOM (rdeboer180): per-entry absorption pattern; revert by removing this field end-to-end
        self.grams = grams
        self.startDate = startDate
        self.uuid = uuid
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.userCreatedDate = userCreatedDate
        self.userUpdatedDate = userUpdatedDate
        self.userDeletedDate = userDeletedDate
        self.operation = operation
        self.addedDate = addedDate
        self.supercededDate = supercededDate
    }

    public var quantity: HKQuantity { HKQuantity(unit: .gram(), doubleValue: grams) }
}

extension SyncCarbObject {
    init(managedObject: CachedCarbObject) {
        self.init(absorptionTime: managedObject.absorptionTime,
                  createdByCurrentApp: managedObject.createdByCurrentApp,
                  foodType: managedObject.foodType,
                  grams: managedObject.grams,
                  startDate: managedObject.startDate,
                  uuid: managedObject.uuid,
                  provenanceIdentifier: managedObject.provenanceIdentifier,
                  syncIdentifier: managedObject.syncIdentifier,
                  syncVersion: managedObject.syncVersion,
                  userCreatedDate: managedObject.userCreatedDate,
                  userUpdatedDate: managedObject.userUpdatedDate,
                  userDeletedDate: managedObject.userDeletedDate,
                  operation: managedObject.operation,
                  addedDate: managedObject.addedDate,
                  supercededDate: managedObject.supercededDate,
                  absorptionPatternIdentifier: managedObject.absorptionPatternIdentifier)  // CUSTOM (rdeboer180): per-entry absorption pattern; revert by removing this field end-to-end
    }
}
