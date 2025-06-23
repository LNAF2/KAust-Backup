//
//  PlaylistEntity+CoreDataProperties.swift
//  
//
//  Created by Erling Breaden on 23/6/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension PlaylistEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistEntity> {
        return NSFetchRequest<PlaylistEntity>(entityName: "PlaylistEntity")
    }

    @NSManaged public var dateCreated: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var lastModifiedDate: Date?
    @NSManaged public var name: String?
    @NSManaged public var owner: UserEntity?
    @NSManaged public var songs: NSOrderedSet?

}

// MARK: Generated accessors for songs
extension PlaylistEntity {

    @objc(insertObject:inSongsAtIndex:)
    @NSManaged public func insertIntoSongs(_ value: SongEntity, at idx: Int)

    @objc(removeObjectFromSongsAtIndex:)
    @NSManaged public func removeFromSongs(at idx: Int)

    @objc(insertSongs:atIndexes:)
    @NSManaged public func insertIntoSongs(_ values: [SongEntity], at indexes: NSIndexSet)

    @objc(removeSongsAtIndexes:)
    @NSManaged public func removeFromSongs(at indexes: NSIndexSet)

    @objc(replaceObjectInSongsAtIndex:withObject:)
    @NSManaged public func replaceSongs(at idx: Int, with value: SongEntity)

    @objc(replaceSongsAtIndexes:withSongs:)
    @NSManaged public func replaceSongs(at indexes: NSIndexSet, with values: [SongEntity])

    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongEntity)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongEntity)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSOrderedSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSOrderedSet)

}

extension PlaylistEntity : Identifiable {

}
