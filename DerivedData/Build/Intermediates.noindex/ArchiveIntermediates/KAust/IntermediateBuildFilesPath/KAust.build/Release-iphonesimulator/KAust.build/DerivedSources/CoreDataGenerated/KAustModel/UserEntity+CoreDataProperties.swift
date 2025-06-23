//
//  UserEntity+CoreDataProperties.swift
//  
//
//  Created by Erling Breaden on 23/6/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension UserEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }

    @NSManaged public var appleUserID: String?
    @NSManaged public var displayName: String?
    @NSManaged public var email: String?
    @NSManaged public var joinDate: Date?
    @NSManaged public var role: String?
    @NSManaged public var userName: String?
    @NSManaged public var playedSongs: NSSet?
    @NSManaged public var playlists: NSSet?

}

// MARK: Generated accessors for playedSongs
extension UserEntity {

    @objc(addPlayedSongsObject:)
    @NSManaged public func addToPlayedSongs(_ value: PlayedSongEntity)

    @objc(removePlayedSongsObject:)
    @NSManaged public func removeFromPlayedSongs(_ value: PlayedSongEntity)

    @objc(addPlayedSongs:)
    @NSManaged public func addToPlayedSongs(_ values: NSSet)

    @objc(removePlayedSongs:)
    @NSManaged public func removeFromPlayedSongs(_ values: NSSet)

}

// MARK: Generated accessors for playlists
extension UserEntity {

    @objc(addPlaylistsObject:)
    @NSManaged public func addToPlaylists(_ value: PlaylistEntity)

    @objc(removePlaylistsObject:)
    @NSManaged public func removeFromPlaylists(_ value: PlaylistEntity)

    @objc(addPlaylists:)
    @NSManaged public func addToPlaylists(_ values: NSSet)

    @objc(removePlaylists:)
    @NSManaged public func removeFromPlaylists(_ values: NSSet)

}

extension UserEntity : Identifiable {

}
