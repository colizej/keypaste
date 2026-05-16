import AppKit
import SwiftUI

struct TriggerEditorView: View {
    let trigger: Trigger
    let onSave: (Trigger) -> Void
    let onDelete: () -> Void

    @State private var triggerKey: String = ""
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var scope: String? = nil
    @State private var runningApps: [AppOption] = []

    private struct AppOption: Hashable, Identifiable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            field(label: "Trigger",
                  placeholder: "e.g. email",
                  text: $triggerKey,
                  mono: true)
            field(label: "Title",
                  placeholder: "Optional",
                  text: $title)

            HStack(alignment: .firstTextBaseline) {
                Text("Scope")
                    .frame(width: 70, alignment: .trailing)
                    .foregroundColor(.secondary)
                Picker("", selection: $scope) {
                    Text("Any app").tag(String?.none)
                    if !runningApps.isEmpty {
                        Divider()
                        ForEach(runningApps) { app in
                            Text(app.name).tag(Optional(app.bundleID))
                        }
                    }
                    // Show the current scope even if its app isn't running
                    // right now — otherwise the Picker silently switches
                    // back to "Any app" and overwrites the user's choice.
                    if let s = scope,
                       !runningApps.contains(where: { $0.bundleID == s }) {
                        Divider()
                        Text("\(s) (not running)").tag(Optional(s))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $content)
                    .font(.body.monospaced())
                    .frame(minHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Tokens: {{clipboard}} {{name}} {{date}} {{time}} {{uuid}} {{cursor}} {{enter}} {{tab}}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                ScrollView {
                    Text(renderedPreview.isEmpty ? "(empty)" : renderedPreview)
                        .font(.body.monospaced())
                        .foregroundColor(renderedPreview.isEmpty
                                         ? .secondary
                                         : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        // .fixedSize on the vertical axis forces Text to
                        // allocate full height for every line break,
                        // including consecutive \n\n. Without this,
                        // SwiftUI compresses empty lines and they
                        // visually disappear from the preview.
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                }
                .frame(minHeight: 80, maxHeight: 140)
                .background(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3))
                )
            }

            HStack {
                Button("Delete", role: .destructive, action: onDelete)
                    .keyboardShortcut(.delete, modifiers: .command)
                Spacer()
                Button("Save", action: saveAction)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(triggerKey.isEmpty)
            }
        }
        .padding(16)
        .onAppear {
            loadFields()
            loadRunningApps()
        }
    }

    private func loadRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppOption? in
                guard let bid = app.bundleIdentifier else { return nil }
                let name = app.localizedName ?? bid
                return AppOption(bundleID: bid, name: name)
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func field(label: String,
                       placeholder: String,
                       text: Binding<String>,
                       mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 70, alignment: .trailing)
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(mono ? .body.monospaced() : .body)
        }
    }

    // Live-rendered preview using the same Template pass as production.
    // Clipboard is read at every body recomputation; cheap and means the
    // preview reflects whatever is currently in the system pasteboard.
    // {{cursor}} is shown as `▏` so the user can see where the caret
    // will land — production paste actually strips it.
    private var renderedPreview: String {
        let ctx = Template.Context(
            clipboard: NSPasteboard.general.string(forType: .string) ?? "",
            username: NSUserName(),
            date: Date()
        )
        let rendered = Template.render(content, context: ctx)
        guard let offset = rendered.cursorOffset else { return rendered.text }
        var out = rendered.text
        let idx = out.index(out.startIndex, offsetBy: offset)
        out.insert("\u{258F}", at: idx)  // ▏ left one-eighth block
        return out
    }

    private func loadFields() {
        triggerKey = trigger.trigger
        title = trigger.title
        content = trigger.content
        scope = trigger.scope
    }

    private func saveAction() {
        var updated = trigger
        updated.trigger = triggerKey
        updated.title = title
        updated.content = content
        updated.scope = scope
        onSave(updated)
    }
}
