import SwiftUI

/// "45m", "1h", "1h 31m" (rounded up, so a countdown never shows 0m).
func duration(_ seconds: TimeInterval) -> String {
    let m = max(Int((seconds / 60).rounded(.up)), 1)
    return m < 60 ? "\(m)m" : m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
}

extension Event {
    var color: Color { Color(hex: colorHex) ?? .accentColor }

    var timeRange: String {
        isAllDay ? "All day" : "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    /// "16:30–17:00 • Work – Meetings • Google Meet"
    var details: String { [timeRange, calendar, meetingName].compactMap { $0 }.joined(separator: " • ") }
}

extension Color {
    init?(hex: String?) {
        guard let hex, let v = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) else { return nil }
        self.init(red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// Small borderless icon button with a hover highlight.
struct IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(hovering ? 0.1 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .onHover { hovering = $0 }
    }
}

extension View {
    /// Padding, hover highlight and hit area shared by list rows.
    func rowStyle(hovering: Binding<Bool>) -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(hovering.wrappedValue ? 0.06 : 0))
            )
            .contentShape(Rectangle())
            .onHover { hovering.wrappedValue = $0 }
    }
}

struct ErrorBanner: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if let error = state.error {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(error)
                    .font(.system(size: 11.5))
                    .textSelection(.enabled)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                IconButton(systemName: "xmark", help: "Dismiss") { state.error = nil }
                    .frame(width: 20, height: 20)
            }
            .padding(10)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }
}
