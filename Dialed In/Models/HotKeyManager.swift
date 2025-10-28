import AppKit
import Carbon

final class HotKeyManager {
    enum HotKeyError: Error, Equatable {
        case missingModifiers
        case registrationFailed
    }

    struct Configuration: Equatable {
        var keyCode: UInt32
        var modifiers: NSEvent.ModifierFlags
    }

    static let shared = HotKeyManager()
    static let defaultConfiguration = Configuration(
        keyCode: UInt32(kVK_Escape),
        modifiers: [.control, .option, .command]
    )

    private let storageKey = "dialedIn.escapeHotKey"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var configuration: Configuration

    var onActivate: (() -> Void)?

    var currentConfiguration: Configuration { configuration }

    private init() {
        configuration = HotKeyManager.loadStoredConfiguration(key: storageKey) ?? HotKeyManager.defaultConfiguration
    }

    func registerStoredHotKey() {
        _ = installHotKey(for: configuration)
    }

    func updateHotKey(configuration newConfiguration: Configuration) throws {
        let sanitized = HotKeyManager.sanitized(configuration: newConfiguration)
        guard !sanitized.modifiers.isEmpty else {
            throw HotKeyError.missingModifiers
        }

        guard installHotKey(for: sanitized) else {
            throw HotKeyError.registrationFailed
        }

        configuration = sanitized
        HotKeyManager.store(configuration: configuration, key: storageKey)
    }

    func displayString(for configuration: Configuration) -> String {
        let mods = HotKeyManager.modifierSymbols(from: configuration.modifiers)
        let key = HotKeyManager.keyName(for: configuration.keyCode)
        return mods + key
    }

    func sanitizedModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        HotKeyManager.sanitizedModifiers(flags)
    }

    @discardableResult
    private func installHotKey(for configuration: Configuration) -> Bool {
        unregister()

        var localHotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(signature: OSType("DInH".fourCharCodeValue), id: UInt32(1))
        let carbonModifiers = carbonFlags(from: configuration.modifiers)

        let status = RegisterEventHotKey(configuration.keyCode, carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &localHotKeyRef)

        guard status == noErr, let localHotKeyRef else {
            return false
        }

        hotKeyRef = localHotKeyRef

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData else { return OSStatus(noErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotKey(event: event)
            return OSStatus(noErr)
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventSpec, selfPointer, &eventHandlerRef)

        guard installStatus == noErr else {
            unregister()
            return false
        }

        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    private func handleHotKey(event: EventRef?) {
        guard event != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onActivate?()
        }
    }

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        return carbonFlags
    }

    private static func sanitized(configuration: Configuration) -> Configuration {
        Configuration(keyCode: configuration.keyCode, modifiers: sanitizedModifiers(configuration.modifiers))
    }

    private static func sanitizedModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return flags.intersection(mask)
    }

    private static func store(configuration: Configuration, key: String) {
        let payload: [String: Any] = [
            "keyCode": Int(configuration.keyCode),
            "modifiers": configuration.modifiers.rawValue
        ]
        UserDefaults.standard.set(payload, forKey: key)
    }

    private static func loadStoredConfiguration(key: String) -> Configuration? {
        guard let payload = UserDefaults.standard.dictionary(forKey: key),
              let keyCodeValue = payload["keyCode"] as? Int,
              let modifiersValue = payload["modifiers"] as? UInt
        else {
            return nil
        }
        return Configuration(keyCode: UInt32(keyCodeValue), modifiers: NSEvent.ModifierFlags(rawValue: modifiersValue))
    }

    private static func modifierSymbols(from flags: NSEvent.ModifierFlags) -> String {
        var components: [String] = []
        if flags.contains(.control) { components.append("⌃") }
        if flags.contains(.option) { components.append("⌥") }
        if flags.contains(.shift) { components.append("⇧") }
        if flags.contains(.command) { components.append("⌘") }
        return components.joined()
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_ForwardDelete): return "Del"
        case UInt32(kVK_Help): return "Help"
        case UInt32(kVK_LeftArrow): return "←"
        case UInt32(kVK_RightArrow): return "→"
        case UInt32(kVK_UpArrow): return "↑"
        case UInt32(kVK_DownArrow): return "↓"
        case UInt32(kVK_F1)...UInt32(kVK_F20):
            return "F" + String(Int(keyCode - UInt32(kVK_F1) + 1))
        case UInt32(kVK_ANSI_0)...UInt32(kVK_ANSI_9):
            let digit = Int(keyCode - UInt32(kVK_ANSI_0))
            return String(digit)
        case UInt32(kVK_ANSI_A)...UInt32(kVK_ANSI_Z):
            let unicodeScalar = UnicodeScalar(Int(keyCode - UInt32(kVK_ANSI_A)) + 65)!
            return String(unicodeScalar)
        default:
            return String(format: "KeyCode %d", keyCode)
        }
    }
}

private extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for scalar in unicodeScalars {
            result = (result << 8) | UInt32(scalar.value)
        }
        return result
    }
}
