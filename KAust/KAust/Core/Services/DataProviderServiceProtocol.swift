//
//  DataProviderServiceProtocol.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import Foundation
import CoreData // For NSManagedObjectID if needed for specific operations

// Protocol for all data interactions (Core Data and local file system)
protocol DataProviderServiceProtocol {

    // MARK: - User Management
    func fetchOrCreateUser(appleUserID: String, userName: String?, role: String) async throws -> UserEntity
    func fetchUser(appleUserID: String) async throws -> UserEntity?
    func updateUserRole(appleUserID: String, newRole: String) async throws

    // MARK: - Song Management
    func importSong(title: String, artist: String?, duration: Float, filePath: String, lrcFilePath: String?,
                    year: Int16?, language: String?, event: String?,
                    genres: [String]) async throws -> SongEntity
    func fetchAllSongs(sortedBy key: String?, ascending: Bool) async throws -> [SongEntity]
    func fetchSongs(matching searchText: String?,
                    filteredByDecade: Int?, year: Int16?, language: String?, event: String?, genreNames: [String]?) async throws -> [SongEntity]
    func fetchSong(with id: UUID) async throws -> SongEntity?
    func deleteSong(_ song: SongEntity) async throws // Also deletes associated MP4/LRC files
    func updateSongPlayCount(songID: UUID) async throws

    // MARK: - Playlist Management
    func fetchOrCreatePlaylist(name: String, forUser user: UserEntity) async throws -> PlaylistEntity
    func addSong(_ song: SongEntity, toPlaylist playlist: PlaylistEntity) async throws
    func removeSong(_ song: SongEntity, fromPlaylist playlist: PlaylistEntity) async throws
    func reorderSongs(inPlaylist playlist: PlaylistEntity, newOrderedSongs: NSOrderedSet) async throws
    func clearPlaylist(_ playlist: PlaylistEntity) async throws

    // MARK: - Played Song History
    func addPlayedSong(song: SongEntity, forUser user: UserEntity, playedDate: Date) async throws -> PlayedSongEntity
    func fetchPlayHistory(forUser user: UserEntity, limit: Int?) async throws -> [PlayedSongEntity]
    func clearPlayHistory(forUser user: UserEntity) async throws

    // MARK: - Genre Management
    func fetchOrCreateGenre(name: String) async throws -> GenreEntity
    func fetchAllGenres() async throws -> [GenreEntity]

    // MARK: - Filter Genre Mapping
    func createFilterGenreMapping(filterCategoryName: String, mapsToGenreNames: [String], displayOrder: Int16?) async throws -> FilterGenreMappingEntity
    func fetchFilterGenreMappings() async throws -> [FilterGenreMappingEntity]
    func mapGenre(_ genre: GenreEntity, toFilterMapping filterMapping: FilterGenreMappingEntity) async throws
    
    // MARK: - File Management (related to Core Data entries)
    // Note: Actual file system operations might be handled within these methods or by a separate utility
    // For example, deleteSong would also trigger deletion of the MP4 from disk.
    // importSong would involve copying the file to the app's sandbox.
}
