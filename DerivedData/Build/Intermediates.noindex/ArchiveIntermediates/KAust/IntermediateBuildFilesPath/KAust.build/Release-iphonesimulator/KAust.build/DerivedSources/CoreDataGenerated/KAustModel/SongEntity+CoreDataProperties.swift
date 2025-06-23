//
//  SongEntity+CoreDataProperties.swift
//  
//
//  Created by Erling Breaden on 23/6/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension SongEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongEntity> {
        return NSFetchRequest<SongEntity>(entityName: "SongEntity")
    }

    @NSManaged public var artist: String?
    @NSManaged public var audioBitRate: Int32
    @NSManaged public var audioChannelCount: Int16
    @NSManaged public var contentRating: Int16
    @NSManaged public var dateAdded: Date?
    @NSManaged public var duration: Double
    @NSManaged public var event: String?
    @NSManaged public var filePath: String?
    @NSManaged public var fileSizeBytes: Int64
    @NSManaged public var id: UUID?
    @NSManaged public var isDownloaded: Bool
    @NSManaged public var language: String?
    @NSManaged public var lastPlayedDate: Date?
    @NSManaged public var lastUsedDate: Date?
    @NSManaged public var lrcFilePath: String?
    @NSManaged public var mediaTypes: NSObject?
    @NSManaged public var pixelHeight: Int32
    @NSManaged public var pixelWidth: Int32
    @NSManaged public var playCount: Int32
    @NSManaged public var title: String?
    @NSManaged public var totalBitRate: Int32
    @NSManaged public var useCount: Int32
    @NSManaged public var usedDates: NSObject?
    @NSManaged public var videoBitRate: Int32
    @NSManaged public var year: Int16
    @NSManaged public var genres: NSSet?
    @NSManaged public var playHistory: NSSet?
    @NSManaged public var playlists: NSSet?

}

// MARK: Generated accessors for genres
extension SongEntity {

    @objc(addGenresObject:)
    @NSManaged public func addToGenres(_ value: GenreEntity)

    @objc(removeGenresObject:)
    @NSManaged public func removeFromGenres(_ value: GenreEntity)

    @objc(addGenres:)
    @NSManaged public func addToGenres(_ values: NSSet)

    @objc(removeGenres:)
    @NSManaged public func removeFromGenres(_ values: NSSet)

}

// MARK: Generated accessors for playHistory
extension SongEntity {

    @objc(addPlayHistoryObject:)
    @NSManaged public func addToPlayHistory(_ value: PlayedSongEntity)

    @objc(removePlayHistoryObject:)
    @NSManaged public func removeFromPlayHistory(_ value: PlayedSongEntity)

    @objc(addPlayHistory:)
    @NSManaged public func addToPlayHistory(_ values: NSSet)

    @objc(removePlayHistory:)
    @NSManaged public func removeFromPlayHistory(_ values: NSSet)

}

// MARK: Generated accessors for playlists
extension SongEntity {

    @objc(addPlaylistsObject:)
    @NSManaged public func addToPlaylists(_ value: PlaylistEntity)

    @objc(removePlaylistsObject:)
    @NSManaged public func removeFromPlaylists(_ value: PlaylistEntity)

    @objc(addPlaylists:)
    @NSManaged public func addToPlaylists(_ values: NSSet)

    @objc(removePlaylists:)
    @NSManaged public func removeFromPlaylists(_ values: NSSet)

}

extension SongEntity : Identifiable {

}
