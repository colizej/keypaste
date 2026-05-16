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
                    .frame(minHeight: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }

            Text("Tokens: {{clipboard}}, {{name}}, {{date}}")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Delete", role: .destructive, action: onDelete)
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
