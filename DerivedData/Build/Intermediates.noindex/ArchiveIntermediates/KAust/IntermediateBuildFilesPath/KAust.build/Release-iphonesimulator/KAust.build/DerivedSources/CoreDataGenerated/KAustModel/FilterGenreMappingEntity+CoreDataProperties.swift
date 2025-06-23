//
//  FilterGenreMappingEntity+CoreDataProperties.swift
//  
//
//  Created by Erling Breaden on 23/6/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension FilterGenreMappingEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FilterGenreMappingEntity> {
        return NSFetchRequest<FilterGenreMappingEntity>(entityName: "FilterGenreMappingEntity")
    }

    @NSManaged public var displayOrder: Int16
    @NSManaged public var filterCategoryName: String?
    @NSManaged public var id: UUID?
    @NSManaged public var mappedGenres: NSSet?

}

// MARK: Generated accessors for mappedGenres
extension FilterGenreMappingEntity {

    @objc(addMappedGenresObject:)
    @NSManaged public func addToMappedGenres(_ value: GenreEntity)

    @objc(removeMappedGenresObject:)
    @NSManaged public func removeFromMappedGenres(_ value: GenreEntity)

    @objc(addMappedGenres:)
    @NSManaged public func addToMappedGenres(_ values: NSSet)

    @objc(removeMappedGenres:)
    @NSManaged public func removeFromMappedGenres(_ values: NSSet)

}

extension FilterGenreMappingEntity : Identifiable {

}
