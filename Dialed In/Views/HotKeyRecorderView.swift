import SwiftUI
import AppKit

struct HotKeyRecorderRow: View {
    @Binding var configuration: HotKeyManager.Configuration

    @State private var isRecording = false
    @State private var displayText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session escape shortcut")
                        .font(Typography.body)
                        .foregroundColor(Palette.textPrimary)
                    Text("Press to end a focus session instantly.")
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }

                Spacer()

                Button {
                    isRecording.toggle()
                } label: {
                    Text(isRecording ? "Listening…" : displayText)
                        .font(Typography.caption)
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                                .fill(Palette.sidebarHighlight.opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
                .overlay(
                    HotKeyCaptureRepresentable(isRecording: $isRecording) { newConfig in
                        do {
                            try HotKeyManager.shared.updateHotKey(configuration: newConfig)
                            configuration = HotKeyManager.shared.currentConfiguration
                            displayText = HotKeyManager.shared.displayString(for: configuration)
                        } catch HotKeyManager.HotKeyError.missingModifiers {
                            configuration = HotKeyManager.shared.currentConfiguration
                            displayText = HotKeyManager.shared.displayString(for: configuration)
                        } catch {
                            configuration = HotKeyManager.shared.currentConfiguration
                            displayText = HotKeyManager.shared.displayString(for: configuration)
                        }
                    }
                    .frame(width: 0, height: 0)
                )

                Button("Reset") {
                    let defaultConfig = HotKeyManager.defaultConfiguration
                    if (try? HotKeyManager.shared.updateHotKey(configuration: defaultConfig)) == nil {
                        HotKeyManager.shared.registerStoredHotKey()
                    }
                    configuration = HotKeyManager.shared.currentConfiguration
                    displayText = HotKeyManager.shared.displayString(for: configuration)
                }
                .buttonStyle(.plain)
                .foregroundColor(Palette.accent)
            }

            if isRecording {
                Text("Press a new shortcut…")
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 14)
        .onAppear {
            displayText = HotKeyManager.shared.displayString(for: configuration)
        }
        .onChange(of: configuration) { _, newValue in
            displayText = HotKeyManager.shared.displayString(for: newValue)
        }
    }
}

private struct HotKeyCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (HotKeyManager.Configuration) -> Void

    func makeNSView(context: Context) -> HotKeyCaptureView {
        let view = HotKeyCaptureView()
        view.onCapture = onCapture
        view.onFinished = {
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: HotKeyCaptureView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onFinished = {
            isRecording = false
        }

        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class HotKeyCaptureView: NSView {
    var onCapture: ((HotKeyManager.Configuration) -> Void)?
    var onFinished: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = HotKeyManager.shared.sanitizedModifiers(event.modifierFlags)
        guard !modifiers.isEmpty else { return }
        let config = HotKeyManager.Configuration(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        onCapture?(config)
        onFinished?()
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore to avoid repeated firing
    }
}
