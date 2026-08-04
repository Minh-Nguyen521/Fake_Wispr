import Carbon
import Foundation

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32       // macOS virtual key code (same values as Carbon)
    var carbonModifiers: UInt32  // Carbon modifier mask (cmdKey, optionKey, etc.)
    var displayName: String

    // Default: ⌥Space — works with Carbon (requires at least one modifier)
    static let defaultHotkey = HotkeyConfig(
        keyCode: 49,
        carbonModifiers: UInt32(optionKey),
        displayName: "⌥Space"
    )

    // Use a new key to avoid conflicts with the old CGEventFlags-based format
    private static let userDefaultsKey = "hotkeyConfigV2"

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
