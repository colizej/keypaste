import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Launch KeyPaste at login", isOn: $store.launchAtLogin)
                Text("Reads from SMAppService.mainApp; only effective once the .app is in /Applications.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("General")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Clipboard restore delay")
                        Spacer()
                        Text("\(Int(store.pasteRestoreDelay * 1000)) ms")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $store.pasteRestoreDelay,
                           in: SettingsStore.pasteRestoreDelayRange,
                           step: 0.05)
                    Text("How long KeyPaste waits before putting your old clipboard back. Shorter = faster but risks the target app reading the wrong clipboard on slow machines.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Paste")
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 420, height: 320)
    }
}
