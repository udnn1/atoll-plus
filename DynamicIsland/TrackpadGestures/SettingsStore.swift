import Foundation

final class SettingsStore: ObservableObject {
    static let defaultsKey = "SlidrFree.settings.v1"

    @Published private(set) var settings: AppSettings
    @Published private(set) var lastLoadDiagnostic: String?
    @Published private(set) var lastSaveDiagnostic: String?
    let isNewInstall: Bool

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isNewInstall = defaults.data(forKey: Self.defaultsKey) == nil

        if let data = defaults.data(forKey: Self.defaultsKey) {
            do {
                settings = try decoder.decode(AppSettings.self, from: data).validated()
            } catch {
                settings = .default.validated()
                lastLoadDiagnostic = "Stored settings could not be decoded; defaults restored."
            }
        } else if let data = UserDefaults(suiteName: Self.slidrDomain)?.data(forKey: Self.defaultsKey),
                  let migrated = try? decoder.decode(AppSettings.self, from: data) {
            settings = migrated.validated()
            save(migrated)
        } else {
            var fresh = AppSettings.newInstall
            fresh.experience.onboardingVersion = ExperienceSettings.currentOnboardingVersion
            fresh.experience.hasSeenV04Welcome = true
            settings = fresh.validated()
        }
    }

    static let slidrDomain = "com.slidr.free"

    func save(_ settings: AppSettings) {
        let validated = settings.validated()
        self.settings = validated

        do {
            let data = try encoder.encode(validated)
            defaults.set(data, forKey: Self.defaultsKey)
            lastSaveDiagnostic = nil
        } catch {
            lastSaveDiagnostic = "Settings could not be saved."
        }
    }

    func dismissLoadDiagnostic() {
        lastLoadDiagnostic = nil
    }

    func restoreDefaults() {
        var restored = AppSettings.default
        restored.experience = settings.experience
        save(restored)
    }
}
