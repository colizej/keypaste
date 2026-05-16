import SwiftUI

struct TriggerListView: View {
    @ObservedObject var vm: TriggerListViewModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                TextField("Search…", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
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
                    .help("Add trigger")
                    Spacer()
                    Text("\(vm.triggers.count) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            .frame(minWidth: 220)
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
                    subtitle: "Pick one on the left, or press + to add."
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
