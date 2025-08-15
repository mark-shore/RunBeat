//
//  HeartRateZoneCalculator.swift
//  pulseprompt
//
//  Pure heart rate zone calculation logic - no session state, no timers
//  Stateless service for zone calculations and settings management
//

import Foundation

class HeartRateZoneCalculator {
    
    // MARK: - Zone Calculation
    
    /// Calculate auto zones using heart rate reserve formula
    /// Returns tuple of (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
    static func calculateAutoZones(restingHR: Int, maxHR: Int) -> (Int, Int, Int, Int, Int, Int) {
        let hrReserve = maxHR - restingHR
        
        // Heart rate zone percentages based on HRR (Karvonen formula) - Whoop methodology
        let zone1Lower = restingHR + Int(floor(Double(hrReserve) * 0.40)) // 40% HRR (floor for minimums)
        let zone1Upper = restingHR + Int(round(Double(hrReserve) * 0.60)) // 60% HRR (round for maximums)
        let zone2Upper = restingHR + Int(round(Double(hrReserve) * 0.70)) // 70% HRR  
        let zone3Upper = restingHR + Int(round(Double(hrReserve) * 0.80)) // 80% HRR
        let zone4Upper = restingHR + Int(round(Double(hrReserve) * 0.90)) // 90% HRR
        let zone5Upper = restingHR + Int(round(Double(hrReserve) * 1.00)) // 100% HRR
        
        return (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
    }
    
    /// Determine which zone a BPM reading falls into
    /// Returns nil if below zone 1 minimum
    static func calculateZone(for bpm: Int, 
                             restingHR: Int, 
                             maxHR: Int, 
                             useAutoZones: Bool,
                             manualZones: (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int)) -> Int? {
        
        let (z1Lower, z1Upper, z2Upper, z3Upper, z4Upper, z5Upper): (Int, Int, Int, Int, Int, Int)
        
        if useAutoZones {
            (z1Lower, z1Upper, z2Upper, z3Upper, z4Upper, z5Upper) = calculateAutoZones(restingHR: restingHR, maxHR: maxHR)
        } else {
            (z1Lower, z1Upper, z2Upper, z3Upper, z4Upper, z5Upper) = manualZones
        }
        
        switch bpm {
        case ..<z1Lower: return nil  // Below zone 1 minimum
        case z1Lower...z1Upper: return 1
        case (z1Upper + 1)...z2Upper: return 2
        case (z2Upper + 1)...z3Upper: return 3
        case (z3Upper + 1)...z4Upper: return 4
        case (z4Upper + 1)...z5Upper: return 5
        case (z5Upper + 1)...: return 5  // Max zone for very high heart rates
        default: return nil
        }
    }
    
    /// Get zone limits for display purposes
    static func getZoneLimits(restingHR: Int, 
                             maxHR: Int, 
                             useAutoZones: Bool,
                             manualZones: (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int)) -> (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int) {
        
        if useAutoZones {
            return calculateAutoZones(restingHR: restingHR, maxHR: maxHR)
        } else {
            return manualZones
        }
    }
    
    /// Log current zone settings for debugging
    static func logZoneSettings(restingHR: Int, 
                               maxHR: Int, 
                               useAutoZones: Bool,
                               manualZones: (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int)) {
        
        if useAutoZones {
            let autoZones = calculateAutoZones(restingHR: restingHR, maxHR: maxHR)
            print("📊 Auto heart rate zones: RHR=\(restingHR), MaxHR=\(maxHR), Zones: Z1(\(autoZones.0)-\(autoZones.1)), Z2(\(autoZones.1+1)-\(autoZones.2)), Z3(\(autoZones.2+1)-\(autoZones.3)), Z4(\(autoZones.3+1)-\(autoZones.4)), Z5(\(autoZones.4+1)-\(autoZones.5))")
        } else {
            let zones = manualZones
            print("📊 Manual heart rate zones: Z1(\(zones.zone1Lower)-\(zones.zone1Upper)), Z2(\(zones.zone1Upper+1)-\(zones.zone2Upper)), Z3(\(zones.zone2Upper+1)-\(zones.zone3Upper)), Z4(\(zones.zone3Upper+1)-\(zones.zone4Upper)), Z5(\(zones.zone4Upper+1)-\(zones.zone5Upper))")
        }
    }
}
