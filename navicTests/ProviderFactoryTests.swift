import Foundation
import Testing
@testable import navic

@MainActor
struct ProviderFactoryTests {
    @Test func navidromeSourceWithoutCredentialsResolvesToDisconnected() throws {
        let settings = makeSettings()
        settings.integrationSource = .navidrome

        let stack = ProviderFactory(settings: settings).build()

        #expect(stack.mode == .disconnected)
        #expect(stack.nowPlaying == nil)
        #expect(stack.artwork == nil)
        #expect(stack.apiClient == nil)
    }

    @Test func navidromeSourceWithCredentialsResolvesToReadOnly() throws {
        let settings = makeSettings()
        settings.integrationSource = .navidrome
        settings.serverURLString = "https://music.example.com"
        settings.username = "max"
        settings.password = "secret"

        let stack = ProviderFactory(settings: settings).build()

        #expect(stack.mode == .navidromeReadOnly)
        #expect(stack.nowPlaying != nil)
        #expect(stack.apiClient != nil)
    }

    @Test func appleMusicSourceWithAvailableAppResolvesToAppleMusic() throws {
        let settings = makeSettings()
        settings.integrationSource = .appleMusic

        var factory = ProviderFactory(settings: settings)
        let stub = StubAppleMusicScripting()
        factory.appleMusicScriptingProvider = { stub }

        let stack = factory.build()

        #expect(stack.mode == .appleMusic)
        #expect(stack.nowPlaying != nil)
        #expect(stack.artwork != nil)
        #expect(stack.apiClient == nil)
    }

    @Test func appleMusicSourceWithoutInstalledAppFallsBackToDisconnected() throws {
        let settings = makeSettings()
        settings.integrationSource = .appleMusic

        var factory = ProviderFactory(settings: settings)
        let stub = StubAppleMusicScripting()
        stub.isMusicAppAvailable = false
        factory.appleMusicScriptingProvider = { stub }

        let stack = factory.build()

        #expect(stack.mode == .disconnected)
        #expect(stack.nowPlaying == nil)
    }

    @Test func switchingSourcePicksTheRightStackEachTime() throws {
        let settings = makeSettings()
        settings.serverURLString = "https://music.example.com"
        settings.username = "max"
        settings.password = "secret"

        var factory = ProviderFactory(settings: settings)
        factory.appleMusicScriptingProvider = { StubAppleMusicScripting() }

        settings.integrationSource = .navidrome
        #expect(factory.build().mode == .navidromeReadOnly)

        settings.integrationSource = .appleMusic
        #expect(factory.build().mode == .appleMusic)

        settings.integrationSource = .auto
        let auto = factory.build()
        #expect(auto.mode == .appleMusic)
        #expect(auto.autoProvider != nil)
        #expect(auto.apiClient != nil)
    }

    @Test func autoSourceWithoutEitherIntegrationResolvesToDisconnected() throws {
        let settings = makeSettings()
        settings.integrationSource = .auto

        var factory = ProviderFactory(settings: settings)
        let stub = StubAppleMusicScripting()
        stub.isMusicAppAvailable = false
        factory.appleMusicScriptingProvider = { stub }

        let stack = factory.build()

        #expect(stack.mode == .disconnected)
        #expect(stack.autoProvider == nil)
    }

    @Test func autoSourceUsesNavidromeWhenAppleMusicMissing() throws {
        let settings = makeSettings()
        settings.serverURLString = "https://music.example.com"
        settings.username = "max"
        settings.password = "secret"
        settings.integrationSource = .auto

        var factory = ProviderFactory(settings: settings)
        let stub = StubAppleMusicScripting()
        stub.isMusicAppAvailable = false
        factory.appleMusicScriptingProvider = { stub }

        let stack = factory.build()

        #expect(stack.mode == .navidromeReadOnly)
        #expect(stack.autoProvider != nil)
    }

    private func makeSettings() -> AppSettings {
        let suiteName = "com.freakware.navic.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        // Unique keychain service id keeps each test's password isolated from
        // both the running app and from every other test in this suite.
        let keychain = KeychainStore(service: "com.freakware.navic.tests.\(UUID().uuidString)")
        return AppSettings(defaults: defaults, keychain: keychain)
    }
}
