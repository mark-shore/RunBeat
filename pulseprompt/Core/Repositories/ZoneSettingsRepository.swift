import Foundation

protocol ZoneSettingsRepository {
    func load() -> ZoneSettings
    func save(_ settings: ZoneSettings)
}


