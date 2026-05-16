import SwiftUI

struct StatsView: View {
    let rows: [Row]
    let totalFires: Int
    let onReset: () -> Void
    let onRefresh: () -> Void

    struct Row: Identifiable {
        let id: String          // trigger.id
        let trigger: String
        let title: String
        let fireCount: Int
        let lastFiredAt: Date?
    }

    private var sortedRows: [Row] {
        rows.sorted { $0.fireCount > $1.fireCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Trigger statistics").font(.headline)
                Text(summaryLine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Refresh", action: onRefresh)
            Button("Reset…", role: .destructive, action: onReset)
        }
        .padding(16)
    }

    private var summaryLine: String {
        let firesLabel = "fire\(totalFires == 1 ? "" : "s")"
        let triggersLabel = "trigger\(rows.count == 1 ? "" : "s")"
        return "\(totalFires) total \(firesLabel) across \(rows.count) \(triggersLabel)"
    }

    @ViewBuilder
    private var content: some View {
        if rows.isEmpty {
            VStack {
                Spacer()
                Text("No triggers have fired yet.")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                columnHeader
                Divider()
                List(sortedRows) { row in
                    StatsRowView(row: row)
                }
                .listStyle(.plain)
            }
        }
    }

    private var columnHeader: some View {
        HStack {
            Text("Trigger").frame(width: 140, alignment: .leading)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading)
            Text("Fires").frame(width: 60, alignment: .trailing)
            Text("Last fired").frame(width: 170, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

private struct StatsRowView: View {
    let row: StatsView.Row

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            Text(row.trigger)
                .font(.body.monospaced())
                .frame(width: 140, alignment: .leading)
                .lineLimit(1)
            Text(row.title.isEmpty ? "—" : row.title)
                .foregroundColor(row.title.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text("\(row.fireCount)")
                .font(.body.monospacedDigit())
                .frame(width: 60, alignment: .trailing)
            Text(lastFiredText)
                .foregroundColor(.secondary)
                .frame(width: 170, alignment: .leading)
                .lineLimit(1)
        }
    }

    private var lastFiredText: String {
        guard let date = row.lastFiredAt else { return "—" }
        return Self.relativeFormatter.localizedString(for: date,
                                                     relativeTo: Date())
    }
}
