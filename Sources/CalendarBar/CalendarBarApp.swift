import SwiftUI

@main
struct CalendarBarApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            RootView().environmentObject(AppState.shared).environmentObject(Updater.shared)
        } label: {
            Image(nsImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The app icon's shapes (header, 3×2 month, today as the Kumpan quarter; see scripts/make-icon.swift)
/// as a template image, so the menu bar tints it.
private let menuBarIcon: NSImage = {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        ctx.translateBy(x: 1, y: 1.4)
        ctx.scaleBy(x: 16 / 750, y: 16 / 750) // the icon's 750-unit design space
        func shape(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: [CGFloat]) {
            ctx.move(to: CGPoint(x: x + r[0], y: y))
            ctx.addArc(tangent1End: CGPoint(x: x + w, y: y), tangent2End: CGPoint(x: x + w, y: y + h), radius: r[1])
            ctx.addArc(tangent1End: CGPoint(x: x + w, y: y + h), tangent2End: CGPoint(x: x, y: y + h), radius: r[2])
            ctx.addArc(tangent1End: CGPoint(x: x, y: y + h), tangent2End: CGPoint(x: x, y: y), radius: r[3])
            ctx.addArc(tangent1End: CGPoint(x: x, y: y), tangent2End: CGPoint(x: x + w, y: y), radius: r[0])
            ctx.closePath()
        }
        let d: CGFloat = 650 / 3
        shape(0, 0, 750, 175, [10, 10, 10, 10])
        for row in 0..<2 {
            for col in 0..<3 {
                let x = CGFloat(col) * (d + 50), y = 225 + CGFloat(row) * (d + 50)
                shape(x, y, d, d, row == 0 && col == 2 ? [10, 10, d - 10, 10] : [d / 2, d / 2, d / 2, d / 2])
            }
        }
        ctx.setFillColor(.black)
        ctx.fillPath()
        return true
    }
    image.isTemplate = true
    return image
}()

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            Updater.shared.startAutomaticChecks()
            AppState.shared.start()
        }
    }
}

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    enum Mode { case main, settings }

    @Published var mode = Mode.main
    /// Signed-in Google and Microsoft accounts (see AccountKey).
    @Published var accounts = Auth.shared.accounts
    @Published var events: [Event] = []
    @Published var error: String?
    @Published var isLoading = false
    /// Ticks every 15 s so countdowns, the Today list and the Meeting Guardian stay current.
    @Published var now = Date()
    private var loadedAt = Date.distantPast
    private var nextRefresh = Date.distantPast

    /// Reloads every 5 minutes (every minute after a failure, e.g. right after wake).
    func start() {
        Task {
            while true {
                now = Date()
                if now >= nextRefresh { await refresh() }
                Guardian.shared.check(events, now: now)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    /// The panel just opened: anything older than a minute is reloaded.
    func refreshIfStale() async {
        if Date().timeIntervalSince(loadedAt) > 60 { await refresh() }
    }

    var signedIn: Bool { !accounts.isEmpty }

    /// Today and tomorrow.
    func refresh() async {
        guard signedIn, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let today = Calendar.current.startOfDay(for: Date())
        do {
            let end = Calendar.current.date(byAdding: .day, value: 2, to: today)!
            let byProvider = Dictionary(grouping: accounts, by: AccountKey.provider)
            async let google = GoogleCalendar.events(accounts: byProvider[.google] ?? [], from: today, to: end,
                                                     namePrimary: accounts.count > 1)
            async let microsoft = MicrosoftCalendar.events(accounts: byProvider[.microsoft] ?? [], from: today, to: end,
                                                           namePrimary: accounts.count > 1)
            let (g, m) = try await (google, microsoft)
            events = (g + m).sorted { $0.start < $1.start }
            error = nil
            loadedAt = Date()
            nextRefresh = loadedAt.addingTimeInterval(300)
        } catch let e as Auth.AuthError { // an account dropped out
            error = e.localizedDescription
            accounts = Auth.shared.accounts
            if !signedIn { events = [] }
            nextRefresh = Date() // load the other accounts on the next tick
        } catch {
            self.error = error.localizedDescription
            nextRefresh = Date().addingTimeInterval(60)
        }
    }

    func addAccount(_ provider: Provider) async {
        error = nil
        do {
            try await Auth.shared.signIn(provider)
            accounts = Auth.shared.accounts
            nextRefresh = .distantPast
            await refresh()
        } catch Auth.AuthError.cancelled {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func remove(_ account: String) async {
        Auth.shared.signOut(account)
        accounts = Auth.shared.accounts
        events = [] // the Meeting Guardian mustn't alert for the removed account's events
        if signedIn { await refresh() } else { mode = .main }
    }
}

/// MenuBarExtra draws its window with the old ~10 pt corners. Clip it to the larger, concentric
/// radius used by macOS 26+ menu bar panels (inner controls use radius = 26 - their 10 pt inset).
let panelCornerRadius: CGFloat = 26

@MainActor private func roundCorners(of window: NSWindow) {
    guard let frame = window.contentView?.superview else { return }
    frame.wantsLayer = true
    frame.layer?.cornerRadius = panelCornerRadius
    frame.layer?.cornerCurve = .continuous
    frame.layer?.masksToBounds = true
    // WindowServer draws the shadow from the window's own corner radius (0 here), not from the layer,
    // so the clipped corners showed the desktop through a square shadow outline. Private, so guarded.
    let setRadius = NSSelectorFromString("_setCornerRadius:")
    if window.responds(to: setRadius), let imp = window.method(for: setRadius) {
        typealias SetRadius = @convention(c) (NSWindow, Selector, CGFloat) -> Void
        unsafeBitCast(imp, to: SetRadius.self)(window, setRadius, panelCornerRadius)
    }
    window.invalidateShadow()
}

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if !state.signedIn { SignInView() }
            else if state.mode == .settings { SettingsView() }
            else { MainView() }
        }
        .frame(width: 360)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { n in
            guard let w = n.object as? NSWindow, w.className.contains("MenuBarExtraWindow") else { return }
            roundCorners(of: w)
            Task { await state.refreshIfStale() }
        }
    }
}
