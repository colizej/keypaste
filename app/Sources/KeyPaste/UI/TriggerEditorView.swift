import AppKit
import SwiftUI

struct TriggerEditorView: View {
    let trigger: Trigger
    let onSave: (Trigger) -> Void
    let onDelete: () -> Void

    @State private var triggerKey: String = ""
    @State private var title: String = ""
    @State private var content: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            field(label: "Trigger",
                  placeholder: "e.g. email",
                  text: $triggerKey,
                  mono: true)
            field(label: "Title",
                  placeholder: "Optional",
                  text: $title)

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
                    Text("Tokens: {{clipboard}}, {{name}}, {{date}}")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .onAppear(perform: loadFields)
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
    }

    private func saveAction() {
        var updated = trigger
        updated.trigger = triggerKey
        updated.title = title
        updated.content = content
        onSave(updated)
    }
}
