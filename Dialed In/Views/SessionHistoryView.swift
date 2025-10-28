import SwiftUI

struct SessionHistoryView: View {
    let records: [SessionRecord]
    private let displayLimit = 5

    private var limitedRecords: [SessionRecord] {
        Array(records.prefix(displayLimit))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Recent Sessions")
                    .font(Typography.headline)
                    .foregroundColor(Palette.textPrimary)
                Spacer()
                if records.count > displayLimit {
                    Text("Showing latest \(displayLimit)")
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(limitedRecords) { record in
                    SessionHistoryRow(record: record)

                    if record.id != limitedRecords.last?.id {
                        Divider().overlay(Palette.divider)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(Palette.sidebarHighlight.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .stroke(Palette.divider.opacity(0.35), lineWidth: 0.8)
                    )
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(Palette.divider.opacity(0.2), lineWidth: 0.6)
                )
        )
    }

    private struct SessionHistoryRow: View {
        let record: SessionRecord

        var body: some View {
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SessionHistoryView.dateFormatter.string(from: record.startedAt))
                        .font(Typography.body)
                        .foregroundColor(Palette.textPrimary)
                    Text(summaryLabel)
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(record.durationMinutes) min")
                        .font(Typography.body)
                        .foregroundColor(Palette.accent)
                    Text(record.mode.rawValue)
                        .font(Typography.caption)
                        .foregroundColor(Palette.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 12)
        }

        private var summaryLabel: String {
            if record.appNames.isEmpty {
                return "No apps selected"
            }
            let first = record.appNames.first ?? ""
            if record.appNames.count == 1 {
                return "Focused on \(first)"
            }
            return "Focused on \(first) +\(record.appNames.count - 1)"
        }
    }
}

struct SessionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let samples = [
            SessionRecord(id: UUID(), startedAt: Date(), durationMinutes: 45, mode: .allowList, appNames: ["Xcode", "Safari"]),
            SessionRecord(id: UUID(), startedAt: Date().addingTimeInterval(-3600), durationMinutes: 30, mode: .blockList, appNames: [])
        ]
        return SessionHistoryView(records: samples)
            .preferredColorScheme(.dark)
            .padding()
    }
}
