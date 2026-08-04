import CoreGraphics
import Foundation

struct HotkeyConfig: Codable, Equatable {
    var keyCode: Int64
    var modifierFlags: UInt64
    var displayName: String

    static let defaultHotkey = HotkeyConfig(
        keyCode: 61,          // Right Option
        modifierFlags: 0,
        displayName: "Right ⌥"
    )

    static let userDefaultsKey = "hotkeyConfig"

    static func load() -> HotkeyConfig {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) else {
            return .defaultHotkey
        }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: HotkeyConfig.userDefaultsKey)
        }
    }
}
