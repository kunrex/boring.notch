//
//  BluetoothIconHelper.swift
//  boringNotch
//
//  Created by Kunal Kashyap on 06/06/26.
//

import Foundation

/// Maps a device class + name to an SF Symbol name. 
enum BluetoothIconHelper {
    static let fallbackSymbol = "antenna.radiowaves.left.and.right"

    // More-specific substrings must come before less-specific ones (first match wins).
    private static let deviceNameRules: [(substring: String, symbol: String)] = [
        ("airpods max",       "airpodsmax"),
        ("airpods pro",       "airpodspro"),
        ("airpods case",      "airpodschargingcase"),
        ("airpods",           "airpods"),
        ("beats studio buds", "beats.studiobuds"),
        ("beats solo buds",   "beats.solobuds"),
        ("beats solo",        "beats.headphones"),
        ("beats studio",      "beats.headphones"),
        ("powerbeats pro",    "beats.powerbeats.pro"),
        ("beats fit pro",     "beats.fitpro"),
        ("beats flex",        "beats.earphones"),
        ("buds",              "earbuds"),
        ("headphone",         "headphones"),
        ("headset",           "headphones"),
        ("speaker",           "hifispeaker.fill"),
        ("keyboard",          "keyboard.fill"),
        ("magic mouse",       "magicmouse.fill"),
        ("mouse",             "computermouse.fill"),
        ("gamepad",           "gamecontroller.fill"),
        ("controller",        "gamecontroller.fill"),
        ("joy-con",           "gamecontroller.fill"),
        ("phone",             "smartphone"),
    ]

    static func SFSymbolName(for deviceClass: UInt32, for deviceName: String) -> String {
        if let icon = SFSymbolFromDevice(deviceName) {
            return icon
        }

        return SFSymbolFromClass(deviceClass)
    }

    // Fallback, deduces the SF Symbol from the Major and Minor Class
    private static func SFSymbolFromClass(_ cod: UInt32) -> String {
        let major = (cod >> 8) & 0x1F
        let minor = (cod >> 2) & 0x3F

        switch major {
        case 0x02: 
            return "iphone"

        case 0x04: 
            switch minor {
            case 0x01, 0x02: return "headphones"        
            case 0x04:       return "microphone"        
            case 0x05:       return "hifispeaker"       
            case 0x06, 0x07: return "airpods"          
            default:         return "hifispeaker"
            }

        case 0x05:  
            let pointingType = (cod >> 6) & 0x03
            switch pointingType {
            case 0x01:       return "keyboard"          
            case 0x02, 0x03: return "computermouse.fill" 
            default:
                return (minor & 0x0F == 0x01 || minor & 0x0F == 0x02)
                    ? "gamecontroller.fill"
                    : fallbackSymbol
            }

        case 0x07:  
            return "applewatch.watchface"

        default:
            return fallbackSymbol
        }
    }

    // Deduces the SF Symbol from the name
    private static func SFSymbolFromDevice(_ deviceName: String) -> String? {
        let name = deviceName.lowercased()
        return deviceNameRules.first(where: { name.contains($0.substring) })?.symbol
    }
}
