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
    private let syncEnabledKey = "dialedIn.syncAcrossDevices"
    private let cloudSyncManager = CloudSyncManager.shared

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var configuration: Configuration

    var onActivate: (() -> Void)?

    var currentConfiguration: Configuration { configuration }

    private init() {
        configuration = HotKeyManager.loadStoredConfiguration(key: storageKey) ?? HotKeyManager.defaultConfiguration
        adoptCloudConfigurationIfNeeded()
        registerForCloudUpdates()
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
        store(configuration: configuration)
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

    private func store(configuration: Configuration) {
        let payload: [String: Any] = [
            "keyCode": Int(configuration.keyCode),
            "modifiers": configuration.modifiers.rawValue
        ]
        UserDefaults.standard.set(payload, forKey: storageKey)
        if syncEnabled {
            let payload = CloudSyncManager.HotKeyPayload(
                keyCode: configuration.keyCode,
                modifiers: configuration.modifiers.rawValue
            )
            cloudSyncManager.setHotKeyConfiguration(payload, enabled: true)
        }
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
        if let mapped = keyDisplayMap[keyCode] {
            return mapped
        }

        switch keyCode {
        case UInt32(kVK_F1)...UInt32(kVK_F20):
            return "F" + String(Int(keyCode - UInt32(kVK_F1) + 1))
        default:
            return String(format: "KeyCode %d", keyCode)
        }
    }

    private static let keyDisplayMap: [UInt32: String] = {
        var map: [UInt32: String] = [
            UInt32(kVK_Escape): "Esc",
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "Return",
            UInt32(kVK_Delete): "Delete",
            UInt32(kVK_Tab): "Tab",
            UInt32(kVK_ForwardDelete): "Del",
            UInt32(kVK_Help): "Help",
            UInt32(kVK_LeftArrow): "←",
            UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑",
            UInt32(kVK_DownArrow): "↓"
        ]

        let digits: [(UInt32, String)] = [
            (UInt32(kVK_ANSI_0), "0"),
            (UInt32(kVK_ANSI_1), "1"),
            (UInt32(kVK_ANSI_2), "2"),
            (UInt32(kVK_ANSI_3), "3"),
            (UInt32(kVK_ANSI_4), "4"),
            (UInt32(kVK_ANSI_5), "5"),
            (UInt32(kVK_ANSI_6), "6"),
            (UInt32(kVK_ANSI_7), "7"),
            (UInt32(kVK_ANSI_8), "8"),
            (UInt32(kVK_ANSI_9), "9")
        ]
        digits.forEach { map[$0.0] = $0.1 }

        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
        for (index, letter) in letters.enumerated() {
            map[UInt32(index)] = letter
        }

        let symbols: [(UInt32, String)] = [
            (UInt32(kVK_ANSI_Minus), "-"),
            (UInt32(kVK_ANSI_Equal), "="),
            (UInt32(kVK_ANSI_LeftBracket), "["),
            (UInt32(kVK_ANSI_RightBracket), "]"),
            (UInt32(kVK_ANSI_Backslash), "\\"),
            (UInt32(kVK_ANSI_Semicolon), ";"),
            (UInt32(kVK_ANSI_Quote), "'"),
            (UInt32(kVK_ANSI_Comma), ","),
            (UInt32(kVK_ANSI_Period), "."),
            (UInt32(kVK_ANSI_Slash), "/"),
            (UInt32(kVK_ANSI_Grave), "`")
        ]
        symbols.forEach { map[$0.0] = $0.1 }

        return map
    }()
}

private extension HotKeyManager {
    var syncEnabled: Bool {
        UserDefaults.standard.bool(forKey: syncEnabledKey)
    }

    func adoptCloudConfigurationIfNeeded() {
        guard syncEnabled,
              let payload = cloudSyncManager.cloudHotKeyConfiguration() else {
            return
        }

        let config = Configuration(keyCode: payload.keyCode, modifiers: NSEvent.ModifierFlags(rawValue: payload.modifiers))
        applyCloudConfiguration(config, shouldStore: false)
    }

    func registerForCloudUpdates() {
        cloudSyncManager.hotKeyConfigurationDidChange = { [weak self] payload in
            guard let self else { return }
            guard self.syncEnabled else { return }
            let newConfig = Configuration(
                keyCode: payload.keyCode,
                modifiers: NSEvent.ModifierFlags(rawValue: payload.modifiers)
            )
            self.applyCloudConfiguration(newConfig, shouldStore: true)
        }
    }

    func applyCloudConfiguration(_ config: Configuration, shouldStore: Bool) {
        guard config != configuration else { return }
        configuration = config
        _ = installHotKey(for: config)
        if shouldStore {
            store(configuration: config)
        } else {
            let payload: [String: Any] = [
                "keyCode": Int(config.keyCode),
                "modifiers": config.modifiers.rawValue
            ]
            UserDefaults.standard.set(payload, forKey: storageKey)
        }
    }
}

extension HotKeyManager {
    func synchronizeWithCloudIfEnabled() {
        adoptCloudConfigurationIfNeeded()
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
