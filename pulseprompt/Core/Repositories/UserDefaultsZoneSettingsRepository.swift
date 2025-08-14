import Foundation

final class UserDefaultsZoneSettingsRepository: ZoneSettingsRepository {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> ZoneSettings {
        let restingHR = userDefaults.object(forKey: "restingHR") as? Int ?? 60
        let maxHR = userDefaults.object(forKey: "maxHR") as? Int ?? 190
        let useAuto = userDefaults.object(forKey: "useAutoZones") as? Bool ?? true

        let z1Lower = userDefaults.object(forKey: "zone1Lower") as? Int ?? 60
        let z1Upper = userDefaults.object(forKey: "zone1Upper") as? Int ?? 70
        let z2Upper = userDefaults.object(forKey: "zone2Upper") as? Int ?? 80
        let z3Upper = userDefaults.object(forKey: "zone3Upper") as? Int ?? 90
        let z4Upper = userDefaults.object(forKey: "zone4Upper") as? Int ?? 100
        let z5Upper = userDefaults.object(forKey: "zone5Upper") as? Int ?? 110

        return ZoneSettings(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAuto,
            manual: (z1Lower: z1Lower, z1Upper: z1Upper, z2Upper: z2Upper, z3Upper: z3Upper, z4Upper: z4Upper, z5Upper: z5Upper)
        )
    }

    func save(_ s: ZoneSettings) {
        userDefaults.set(s.restingHR, forKey: "restingHR")
        userDefaults.set(s.maxHR, forKey: "maxHR")
        userDefaults.set(s.useAutoZones, forKey: "useAutoZones")

        userDefaults.set(s.manual.z1Lower, forKey: "zone1Lower")
        userDefaults.set(s.manual.z1Upper, forKey: "zone1Upper")
        userDefaults.set(s.manual.z2Upper, forKey: "zone2Upper")
        userDefaults.set(s.manual.z3Upper, forKey: "zone3Upper")
        userDefaults.set(s.manual.z4Upper, forKey: "zone4Upper")
        userDefaults.set(s.manual.z5Upper, forKey: "zone5Upper")
    }
}


