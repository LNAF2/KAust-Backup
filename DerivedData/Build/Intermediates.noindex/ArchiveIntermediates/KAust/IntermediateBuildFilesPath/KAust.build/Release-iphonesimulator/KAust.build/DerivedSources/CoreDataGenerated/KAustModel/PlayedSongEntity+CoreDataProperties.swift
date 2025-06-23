//
//  PlayedSongEntity+CoreDataProperties.swift
//  
//
//  Created by Erling Breaden on 23/6/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension PlayedSongEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayedSongEntity> {
        return NSFetchRequest<PlayedSongEntity>(entityName: "PlayedSongEntity")
    }

    @NSManaged public var artistNameSnapshot: String?
    @NSManaged public var id: UUID?
    @NSManaged public var playedDate: Date?
    @NSManaged public var songTitleSnapshot: String?
    @NSManaged public var song: SongEntity?
    @NSManaged public var user: UserEntity?

}

extension PlayedSongEntity : Identifiable {

}
