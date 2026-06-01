import Testing
import Foundation
import UIKit
@testable import KhmNow

@Suite("UI Component and ViewModel Tests", .serialized)
@MainActor
struct UIComponentTests {
    init() {
        // Clear User Defaults for clean runs
        UserDefaults.standard.removeObject(forKey: "gfn.favoriteIds")
        UserDefaults.standard.removeObject(forKey: "gfn.preferredStores")
        UserDefaults.standard.removeObject(forKey: "gfn.recentlyPlayed")
        UserDefaults.standard.removeObject(forKey: "gfn.streamSettings")
    }

    @Test func testGamesViewModelInitialState() {
        UserDefaults.standard.removeObject(forKey: "gfn.favoriteIds")
        UserDefaults.standard.removeObject(forKey: "gfn.preferredStores")
        UserDefaults.standard.removeObject(forKey: "gfn.recentlyPlayed")
        UserDefaults.standard.removeObject(forKey: "gfn.streamSettings")
        let vm = GamesViewModel()
        #expect(vm.mainGames.isEmpty)
        #expect(vm.libraryGames.isEmpty)
        #expect(vm.favoriteIds.isEmpty)
        #expect(vm.recentlyPlayedIds.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test func testGamesViewModelToggleFavorite() {
        let vm = GamesViewModel()
        #expect(!vm.isFavorite("123"))
        
        vm.toggleFavorite("123")
        #expect(vm.isFavorite("123"))
        #expect(vm.favoriteIds.contains("123"))

        vm.toggleFavorite("123")
        #expect(!vm.isFavorite("123"))
    }

    @Test func testGamesViewModelRecentlyPlayed() {
        let vm = GamesViewModel()
        let game = GameInfo(id: "123", title: "Game 123", boxArtUrl: nil, heroBannerUrl: nil, isInLibrary: false, variants: [])
        
        vm.recordPlayed(game)
        #expect(vm.recentlyPlayedIds.first == "123")
        #expect(vm.recentlyPlayedIds.count == 1)
    }

    @Test func testGamesViewModelPreferredStore() {
        let vm = GamesViewModel()
        let variant = GameVariant(id: "v123", appStore: "STEAM", appId: nil)
        let game = GameInfo(id: "g123", title: "Game", boxArtUrl: nil, heroBannerUrl: nil, isInLibrary: false, variants: [variant])

        #expect(!vm.hasPreferredStore(for: game))
        #expect(vm.preferredVariantId(for: game) == "v123")

        vm.setPreferredStore(gameId: "g123", variantId: "v123")
        #expect(vm.hasPreferredStore(for: game))
        #expect(vm.preferredVariantId(for: game) == "v123")
    }

    @Test func testGamesViewModelResolutionsAndFPS() {
        let vm = GamesViewModel()
        
        // Empty subscription returns fallback
        #expect(vm.availableResolutions == ["1280x720", "1920x1080"])
        
        let entitled = [
            EntitledResolution(widthInPixels: 1920, heightInPixels: 1080, framesPerSecond: 60),
            EntitledResolution(widthInPixels: 1280, heightInPixels: 720, framesPerSecond: 120),
            EntitledResolution(widthInPixels: 1920, heightInPixels: 1080, framesPerSecond: 30)
        ]
        let sub = SubscriptionInfo(
            membershipTier: "Ultimate",
            isUnlimited: true,
            remainingMinutes: nil,
            totalMinutes: nil,
            entitledResolutions: entitled
        )
        vm.subscription = sub
        
        // Ordered resolutions
        #expect(vm.availableResolutions == ["1280x720", "1920x1080"])
        
        vm.streamSettings.resolution = "1920x1080"
        #expect(vm.availableFps.contains(30))
        #expect(vm.availableFps.contains(60))
    }
}
