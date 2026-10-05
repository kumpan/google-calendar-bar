import AppKit
import SwiftUI

/// Meeting Guardian: a hard-to-miss glass panel at the top of the screen shortly before important
/// meetings (video link or other guests), with Join and Snooze.
@MainActor
final class Guardian {
    static let shared = Guardian()
    static let enabledKey = "guardianEnabled", leadKey = "guardianLeadMinutes"

    private var panel: NSPanel?
    private var shownEnd: Date?
    private var done: Set<String> = []      // joined or dismissed
    private var snoozed: [String: Date] = [:]

    /// Keyed by start too, so a rescheduled meeting alerts again.
    private static func key(_ e: Event) -> String { "\(e.id)|\(e.start.timeIntervalSince1970)" }

    func check(_ events: [Event], now: Date) {
        if let shownEnd, now >= shownEnd { close() }
        guard panel == nil, UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true else { return }
        let lead = TimeInterval(UserDefaults.standard.object(forKey: Self.leadKey) as? Int ?? 1) * 60
        let due = events.first { e in
            let key = Self.key(e)
            guard e.isImportant, !e.isAllDay, !done.contains(key), now < e.end else { return false }
            if let until = snoozed[key] { return now >= until }
            // Launched mid-meeting: only alert for ones that started in the last 5 minutes.
            return now >= e.start.addingTimeInterval(-lead) && now < e.start.addingTimeInterval(300)
        }
        if let due { show(due) }
    }

    func preview() {
        let start = Date().addingTimeInterval(60)
        show(Event(id: "preview", title: "Daily standup", start: start, end: start.addingTimeInterval(1800), isAllDay: false,
                   calendar: "Preview", colorHex: nil, meetingURL: URL(string: "https://meet.google.com"),
                   meetingName: "Google Meet", link: nil, isImportant: true))
    }

    private func show(_ event: Event) {
        close()
        let key = Self.key(event)
        let alert = GuardianAlert(
            event: event,
            join: { [weak self] in
                if let url = event.meetingURL { NSWorkspace.shared.open(url) }
                self?.done.insert(key); self?.close()
            },
            snooze: { [weak self] in
                self?.snoozed[key] = Date().addingTimeInterval(300); self?.close()
            },
            dismiss: { [weak self] in
                self?.done.insert(key); self?.close()
            })
        let hosting = FirstMouseHostingView(rootView: alert)
        let size = hosting.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.midX - size.width / 2, y: screen.maxY - size.height - 12))
        }
        panel.orderFrontRegardless()
        NSSound(named: "Glass")?.play()
        self.panel = panel
        shownEnd = event.end
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
        shownEnd = nil
    }
}

/// The panel never becomes key; take the first click anyway so one click on Join joins.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct GuardianAlert: View {
    let event: Event
    let join: () -> Void
    let snooze: () -> Void
    let dismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            HStack(spacing: 14) {
                Image(systemName: event.meetingURL == nil ? "person.2.fill" : "video.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(event.color.gradient, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status(at: context.date)).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text(event.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text(event.details).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Button("Snooze 5m", action: snooze).buttonStyle(.glass).controlSize(.large)
                if event.meetingURL != nil {
                    // Glass (even tinted) turns grey in a window that isn't key, so Join gets a solid fill.
                    Button(action: join) {
                        Label("Join", systemImage: "video.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Color.blue.gradient, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
                IconButton(systemName: "xmark", help: "Dismiss", action: dismiss)
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 12)
            .frame(width: 560)
            .glassEffect(.regular, in: .rect(cornerRadius: 34))
        }
        .environment(\.controlActiveState, .key) // the panel is never key; don't draw the buttons dimmed
    }

    private func status(at now: Date) -> String {
        let seconds = event.start.timeIntervalSince(now)
        if seconds > 30 { return "Starts in \(duration(seconds))" }
        if seconds > -60 { return "Starting now" }
        return "Started \(duration(-seconds)) ago"
    }
}
