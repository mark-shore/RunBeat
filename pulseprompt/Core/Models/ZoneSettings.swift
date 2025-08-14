import Foundation

struct ZoneSettings {
    var restingHR: Int
    var maxHR: Int
    var useAutoZones: Bool
    var manual: (z1Lower: Int, z1Upper: Int, z2Upper: Int, z3Upper: Int, z4Upper: Int, z5Upper: Int)
}


