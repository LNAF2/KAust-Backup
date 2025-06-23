//
//  GenreEntity+CoreDataProperties.swift
//  
//
//  Created by Erling Breaden on 23/6/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension GenreEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GenreEntity> {
        return NSFetchRequest<GenreEntity>(entityName: "GenreEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var filterMappings: NSSet?
    @NSManaged public var songs: NSSet?

}

// MARK: Generated accessors for filterMappings
extension GenreEntity {

    @objc(addFilterMappingsObject:)
    @NSManaged public func addToFilterMappings(_ value: FilterGenreMappingEntity)

    @objc(removeFilterMappingsObject:)
    @NSManaged public func removeFromFilterMappings(_ value: FilterGenreMappingEntity)

    @objc(addFilterMappings:)
    @NSManaged public func addToFilterMappings(_ values: NSSet)

    @objc(removeFilterMappings:)
    @NSManaged public func removeFromFilterMappings(_ values: NSSet)

}

// MARK: Generated accessors for songs
extension GenreEntity {

    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongEntity)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongEntity)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSSet)

}

extension GenreEntity : Identifiable {

}
