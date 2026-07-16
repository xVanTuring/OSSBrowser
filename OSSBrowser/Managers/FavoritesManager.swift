//
//  FavoritesManager.swift
//  OSSBrowser
//

import Foundation
import Combine

@MainActor
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @Published private(set) var favorites: [FavoritePath] = []

    private let defaultsKey = "favorites.paths"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    func favorites(for configId: UUID) -> [FavoritePath] {
        favorites.filter { $0.configId == configId }
    }

    func isFavorite(configId: UUID, bucketName: String, path: String) -> Bool {
        favorites.contains {
            $0.configId == configId && $0.bucketName == bucketName && $0.path == path
        }
    }

    func toggleFavorite(configId: UUID, bucketName: String, path: String) {
        if isFavorite(configId: configId, bucketName: bucketName, path: path) {
            favorites.removeAll {
                $0.configId == configId && $0.bucketName == bucketName && $0.path == path
            }
        } else {
            favorites.append(FavoritePath(configId: configId, bucketName: bucketName, path: path))
        }
        save()
    }

    func removeFavorite(_ favorite: FavoritePath) {
        favorites.removeAll { $0.id == favorite.id }
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(favorites)
            defaults.set(data, forKey: defaultsKey)
        } catch {
            print("FavoritesManager: Failed to save favorites: \(error)")
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey) else { return }
        do {
            favorites = try JSONDecoder().decode([FavoritePath].self, from: data)
        } catch {
            print("FavoritesManager: Failed to load favorites: \(error)")
        }
    }
}
