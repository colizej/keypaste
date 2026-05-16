import SwiftUI

struct TriggerListView: View {
    @ObservedObject var vm: TriggerListViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                TextField("Search…", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .padding(8)

                List(selection: $vm.selectedID) {
                    ForEach(vm.filteredTriggers) { trigger in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trigger.trigger)
                                .font(.body.monospaced())
                            Text(trigger.title.isEmpty
                                 ? "Untitled"
                                 : trigger.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .tag(trigger.id)
                    }
                }

                HStack {
                    Button(action: { vm.add() }) {
                        Image(systemName: "plus")
                    }
                    .help("Add trigger (⌘N)")
                    .keyboardShortcut("n", modifiers: .command)
                    Spacer()
                    Text("\(vm.triggers.count) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            .frame(minWidth: 220)
            // Invisible button to capture ⌘F from anywhere in the window
            // and route focus to the search field. SwiftUI's .searchable
            // would be neater but rearranges the sidebar layout; keeping
            // the explicit TextField keeps the visual identical.
            .background(
                Button("") { searchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
            )
        } detail: {
            if let id = vm.selectedID,
               let trigger = vm.triggers.first(where: { $0.id == id }) {
                TriggerEditorView(
                    trigger: trigger,
                    onSave: { vm.save($0) },
                    onDelete: { vm.delete(id: id) }
                )
                .id(trigger.id)
            } else {
                ContentUnavailableViewCompat(
                    title: "No trigger selected",
                    subtitle: "Pick one on the left, or press ⌘N to add."
                )
            }
        }
    }
}

// Tiny shim: ContentUnavailableView is macOS 14+. We target 13.
private struct ContentUnavailableViewCompat: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
