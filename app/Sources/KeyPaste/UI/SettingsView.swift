import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let onInstallPack: (SnippetPack) -> SnippetPacks.InstallResult

    @State private var lastInstall: (packID: String, result: SnippetPacks.InstallResult)? = nil

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

            Section {
                ForEach(SnippetPacks.all) { pack in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name).font(.body)
                            Text(pack.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if case let .some(latest) = lastInstall,
                               latest.packID == pack.id {
                                Text("Added \(latest.result.added), skipped \(latest.result.skipped) duplicate(s)")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        Spacer()
                        Button("Install") {
                            let result = onInstallPack(pack)
                            lastInstall = (pack.id, result)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text("Existing triggers with the same name are skipped — your data is never overwritten. Each pack uses the ;-prefix convention to avoid mid-word firing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Snippet Packs")
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 480, height: 620)
    }
}
