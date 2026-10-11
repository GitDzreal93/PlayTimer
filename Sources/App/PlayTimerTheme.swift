import SwiftUI

enum PlayTimerTheme {
    static let canvas = Color(red: 0.97, green: 0.94, blue: 0.90)
    static let surface = Color(red: 1.00, green: 0.98, blue: 0.95)
    static let ink = Color(red: 0.15, green: 0.23, blue: 0.27)
    static let mutedInk = Color(red: 0.45, green: 0.42, blue: 0.39)
    static let teal = Color(red: 0.17, green: 0.39, blue: 0.39)
    static let softTeal = Color(red: 0.87, green: 0.93, blue: 0.89)
    static let border = Color(red: 0.90, green: 0.86, blue: 0.82)
}

struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PlayTimerTheme.teal, in: RoundedRectangle(cornerRadius: 16))
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.82 : 1)
    }
}
