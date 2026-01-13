import SwiftUI

enum ProteinScore {
    case excellent
    case good
    case moderate
    case low
    case poor

    init(ratio: Double) {
        switch ratio {
        case 15...:
            self = .excellent
        case 10..<15:
            self = .good
        case 5..<10:
            self = .moderate
        case 2..<5:
            self = .low
        default:
            self = .poor
        }
    }

    var color: Color {
        switch self {
        case .excellent:
            return Color(red: 0x22/255, green: 0xC5/255, blue: 0x5E/255) // #22C55E
        case .good:
            return Color(red: 0x84/255, green: 0xCC/255, blue: 0x16/255) // #84CC16
        case .moderate:
            return Color(red: 0xEA/255, green: 0xB3/255, blue: 0x08/255) // #EAB308
        case .low:
            return Color(red: 0xF9/255, green: 0x73/255, blue: 0x16/255) // #F97316
        case .poor:
            return Color(red: 0xEF/255, green: 0x44/255, blue: 0x44/255) // #EF4444
        }
    }

    var label: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .moderate:
            return "Moderate"
        case .low:
            return "Low"
        case .poor:
            return "Poor"
        }
    }
}
