import SwiftUI

/// The event the big card shows: the next one if it starts within 10 minutes, else the one in
/// progress, else the next one. `events` must be sorted by start.
func featuredEvent(_ events: [Event], now: Date) -> Event? {
    let timed = events.filter { !$0.isAllDay && $0.end > now }
    let next = timed.first { $0.start > now }
    if let next, next.start.timeIntervalSince(now) < 600 { return next }
    return timed.first { $0.start <= now } ?? next
}

private func googleCalendar(_ account: String?) -> URL {
    let url = URL(string: "https://calendar.google.com/calendar/r")!
    return account.map { GoogleCalendar.inAccount(url, $0) } ?? url
}

private func open(_ url: URL?) {
    if let url { NSWorkspace.shared.open(url) }
}

struct MainView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var updater: Updater
    @AppStorage(Guardian.enabledKey) private var guardianOn = true
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let event = featuredEvent(state.events, now: state.now) {
                NextCard(event: event, now: state.now).padding([.horizontal, .top], 10)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) { days }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .frame(height: min(listHeight, 380))
            Divider().padding(.horizontal, 18)
            guardianRow
            Divider().padding(.horizontal, 18)
            ErrorBanner().padding(.top, 8)
            footer
        }
    }

    @ViewBuilder private var days: some View {
        let today = Calendar.current.startOfDay(for: state.now)
        ForEach(0..<2, id: \.self) { offset in
            let day = Calendar.current.date(byAdding: .day, value: offset, to: today)!
            let next = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            let items = state.events.filter { $0.start < next && $0.end > day }
            Text(offset == 0 ? "Today" : "Tomorrow")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 2)
            if items.isEmpty {
                Text(state.isLoading ? "Loading…" : "Nothing scheduled")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            ForEach(items) { EventRow(event: $0, now: state.now) }
        }
    }

    private var guardianRow: some View {
        Button { guardianOn.toggle() } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Meeting Guardian").font(.system(size: 13, weight: .medium))
                    Text(guardianOn ? "Active for your important meetings." : "Off. No heads-up before meetings.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: guardianOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(guardianOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if state.accounts.count > 1 {
                Menu {
                    ForEach(state.accounts, id: \.self) { account in
                        Button(account) { open(googleCalendar(account)) }
                    }
                } label: {
                    Label("Google Calendar", systemImage: "arrow.up.forward.app")
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .fixedSize()
            } else {
                Button { open(googleCalendar(state.accounts.first)) } label: {
                    Label("Google Calendar", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.glass)
            }
            Spacer()
            if let release = updater.available {
                Button { state.mode = .settings } label: {
                    Label("Update \(release.version)", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.tint)
            }
            if state.isLoading {
                ProgressView().controlSize(.small).frame(width: 28, height: 28)
            } else {
                IconButton(systemName: "arrow.clockwise", help: "Refresh") { Task { await state.refresh() } }
            }
            IconButton(systemName: "gearshape", help: "Settings") { state.mode = .settings }
        }
        .padding(10)
    }
}

struct NextCard: View {
    let event: Event
    let now: Date

    private var headline: String {
        if event.start <= now { return "Now · ends in \(duration(event.end.timeIntervalSince(now)))" }
        let noun = event.isImportant ? "Next meeting" : "Up next"
        if !Calendar.current.isDate(event.start, inSameDayAs: now) {
            return "\(noun) tomorrow at \(event.start.formatted(date: .omitted, time: .shortened))"
        }
        return "\(noun) in \(duration(event.start.timeIntervalSince(now)))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headline).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(event.title).font(.system(size: 18, weight: .semibold)).lineLimit(2)
            Text(event.details).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            if let url = event.meetingURL {
                Button { open(url) } label: {
                    Label("Join", systemImage: "video.fill").padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(event.color.opacity(0.22)), in: .rect(cornerRadius: panelCornerRadius - 10))
        .contentShape(.rect)
        .onTapGesture { open(event.link) }
        .help("Open in Google Calendar")
    }
}

struct EventRow: View {
    let event: Event
    let now: Date
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Capsule().fill(event.color).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(event.timeRange).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let url = event.meetingURL {
                IconButton(systemName: "video.fill", help: "Join \(event.meetingName ?? "call")") { open(url) }
            }
        }
        .rowStyle(hovering: $hovering)
        .opacity(event.end <= now ? 0.45 : 1)
        .onTapGesture { open(event.link) }
        .help("Open in Google Calendar")
    }
}

struct SignInView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tint)
            VStack(spacing: 4) {
                Text("Connect Google Calendar").font(.system(size: 15, weight: .semibold))
                Text("See what's next and join meetings in one click.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if GoogleAuth.isConfigured {
                Button { Task { await state.addAccount() } } label: {
                    Text("Sign in with Google").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else {
                Text("This build has no Google client ID. See README → For developers.")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = state.error {
                Text(error).font(.system(size: 11.5)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 30)
    }
}
