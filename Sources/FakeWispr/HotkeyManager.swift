import CoreGraphics
import ApplicationServices
import Foundation

class HotkeyManager {
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    fileprivate var eventTap: CFMachPort?
    private var isKeyDown = false
    private(set) var config: HotkeyConfig

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        self.config = HotkeyConfig.load()
    }

    func updateConfig(_ newConfig: HotkeyConfig) {
        config = newConfig
        newConfig.save()
        isKeyDown = false
    }

    /// Starts the event tap. If accessibility isn't granted yet, polls every second until it is.
    func start() {
        if AXIsProcessTrusted() {
            activate()
        } else {
            // Trigger the system prompt ONCE so macOS adds us to the Accessibility list
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            pollUntilTrusted()
        }
    }

    private func pollUntilTrusted() {
        guard !AXIsProcessTrusted() else { activate(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.pollUntilTrusted() }
    }

    private func activate() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passRetained(self).toOpaque()
        ) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.activate() }
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> CGEvent? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Right Option fires as flagsChanged
        if type == .flagsChanged && config.keyCode == 61 {
            let flags = event.flags
            let pressed = flags.contains(.maskAlternate) && keyCode == 61

            if pressed && !isKeyDown {
                isKeyDown = true
                onKeyDown()
                return nil
            } else if !pressed && isKeyDown {
                isKeyDown = false
                onKeyUp()
                return nil
            }
            return event
        }

        // Other keys fire as keyDown/keyUp
        if keyCode == config.keyCode {
            let modifiersMatch = matchesModifiers(event: event)
            if type == .keyDown && !isKeyDown && modifiersMatch {
                isKeyDown = true
                onKeyDown()
                return nil
            } else if type == .keyUp && isKeyDown {
                isKeyDown = false
                onKeyUp()
                return nil
            }
        }

        return event
    }

    private func matchesModifiers(event: CGEvent) -> Bool {
        let flags = event.flags
        let required = CGEventFlags(rawValue: config.modifierFlags)
        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        return flags.intersection(relevant) == required.intersection(relevant)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    if let result = manager.handle(type: type, event: event) {
        return Unmanaged.passRetained(result)
    }
    return nil
}
