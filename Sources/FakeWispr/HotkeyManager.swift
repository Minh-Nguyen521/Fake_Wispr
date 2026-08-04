import Carbon
import Foundation

class HotkeyManager {
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    private(set) var config: HotkeyConfig
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        self.config = HotkeyConfig.load()
    }

    func start() {
        installHandler()
        register()
    }

    func updateConfig(_ newConfig: HotkeyConfig) {
        config = newConfig
        newConfig.save()
        unregister()
        register()
    }

    // MARK: - Private

    private func installHandler() {
        guard eventHandlerRef == nil else { return }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), carbonHotkeyCallback, 2, &types, selfPtr, &eventHandlerRef)
    }

    private func register() {
        let hkID = EventHotKeyID(signature: fourCC("FWSP"), id: 1)
        RegisterEventHotKey(config.keyCode, config.carbonModifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        _ = hotKeyRef.map { UnregisterEventHotKey($0) }
        hotKeyRef = nil
    }

    fileprivate func handleKeyDown() { DispatchQueue.main.async { self.onKeyDown() } }
    fileprivate func handleKeyUp()   { DispatchQueue.main.async { self.onKeyUp() } }
}

// Top-level C-compatible callback required by Carbon
private func carbonHotkeyCallback(
    _: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    switch GetEventKind(event) {
    case UInt32(kEventHotKeyPressed):  manager.handleKeyDown()
    case UInt32(kEventHotKeyReleased): manager.handleKeyUp()
    default: break
    }
    return noErr
}

private func fourCC(_ s: StaticString) -> FourCharCode {
    s.withUTF8Buffer { buf in
        buf.prefix(4).reduce(FourCharCode(0)) { ($0 << 8) | FourCharCode($1) }
    }
}
