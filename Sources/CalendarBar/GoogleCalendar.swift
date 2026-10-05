import Foundation

struct Event: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    /// Calendar name; nil for the primary calendar.
    let calendar: String?
    let colorHex: String?
    let meetingURL: URL?
    /// "Google Meet", "Zoom", …
    let meetingName: String?
    /// The event in Google Calendar on the web.
    let link: URL?
    /// Has a video link or other guests. The Meeting Guardian only alerts for these.
    let isImportant: Bool
}

/// Read-only Google Calendar API v3 client.
enum GoogleCalendar {
    struct CalendarList: Decodable { let items: [Entry] }
    struct Entry: Decodable {
        let id: String
        let summary: String?
        let summaryOverride: String?
        let backgroundColor: String?
        let selected: Bool?
        let primary: Bool?
    }

    struct EventList: Decodable { let items: [APIEvent] }
    struct APIEvent: Decodable {
        struct Time: Decodable { let dateTime: String?; let date: String? }
        struct Attendee: Decodable {
            let isSelf: Bool?
            let responseStatus: String?
            enum CodingKeys: String, CodingKey { case isSelf = "self", responseStatus }
        }
        struct Conference: Decodable {
            struct EntryPoint: Decodable { let entryPointType: String?; let uri: String? }
            struct Solution: Decodable { let name: String? }
            let entryPoints: [EntryPoint]?
            let conferenceSolution: Solution?
        }
        let id: String
        let iCalUID: String?
        let summary: String?
        let start: Time?
        let end: Time?
        let colorId: String?
        let hangoutLink: String?
        let conferenceData: Conference?
        let location: String?
        let description: String?
        let htmlLink: String?
        let attendees: [Attendee]?
        let eventType: String?
    }

    private struct Failure: Decodable {
        struct Body: Decodable { let message: String }
        let error: Body
    }

    /// The event colours Google Calendar shows today (the API's /colors endpoint still returns old pastels).
    static let eventColors = ["1": "#7986CB", "2": "#33B679", "3": "#8E24AA", "4": "#E67C73", "5": "#F6BF26", "6": "#F4511E",
                              "7": "#039BE5", "8": "#616161", "9": "#3F51B5", "10": "#0B8043", "11": "#D50000"]

    static let providers = ["meet.google.com": "Google Meet", "zoom.us": "Zoom", "teams.microsoft.com": "Microsoft Teams",
                            "teams.live.com": "Microsoft Teams", "webex.com": "Webex", "whereby.com": "Whereby",
                            "chime.aws": "Amazon Chime", "gotomeeting.com": "GoTo Meeting"]

    /// Events from the calendars ticked in each account's Google Calendar sidebar, sorted by start.
    static func events(accounts: [String], from start: Date, to end: Date) async throws -> [Event] {
        // Accounts in the order they were added, each with its primary calendar first: the first copy
        // of an event that is on several calendars (a colleague's, or both your accounts) wins.
        var calendars: [(account: String, entry: Entry)] = []
        for account in accounts {
            calendars += try await get(CalendarList.self, "users/me/calendarList", [], account: account).items
                .filter { $0.selected == true }
                .sorted { $0.primary == true && $1.primary != true }
                .map { (account, $0) }
        }
        let iso = ISO8601DateFormatter() // UTC "…Z": no "+" to mangle in the query string
        let query = [URLQueryItem(name: "timeMin", value: iso.string(from: start)),
                     URLQueryItem(name: "timeMax", value: iso.string(from: end)),
                     URLQueryItem(name: "singleEvents", value: "true"),
                     URLQueryItem(name: "orderBy", value: "startTime"),
                     URLQueryItem(name: "maxResults", value: "250")] // ponytail: no paging, 250 per calendar is plenty for two days
        let lists = try await withThrowingTaskGroup(of: (Int, [APIEvent]).self) { group in
            for (i, calendar) in calendars.enumerated() {
                let id = calendar.entry.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/")))!
                group.addTask { (i, try await get(EventList.self, "calendars/\(id)/events", query, account: calendar.account).items) }
            }
            return try await group.reduce(into: [Int: [APIEvent]]()) { $0[$1.0] = $1.1 }
        }
        var seen = Set<String>()
        let events = calendars.indices.flatMap { i in
            (lists[i] ?? [])
                .filter { seen.insert("\($0.iCalUID ?? $0.id)|\($0.start?.dateTime ?? $0.start?.date ?? "")").inserted }
                .compactMap { makeEvent($0, calendar: calendars[i].entry, account: calendars[i].account, namePrimary: accounts.count > 1) }
        }
        return events.sorted { $0.start < $1.start }
    }

    /// `account` is the one the event was loaded through; its Google links open in that account.
    /// The primary calendar goes unnamed, unless there are several accounts to tell apart.
    static func makeEvent(_ e: APIEvent, calendar: Entry, account: String, namePrimary: Bool = false) -> Event? {
        guard e.eventType != "workingLocation",
              e.attendees?.first(where: { $0.isSelf == true })?.responseStatus != "declined",
              let startTime = e.start, let start = date(startTime), let end = e.end.flatMap(date) else { return nil }
        let meeting = meetingLink(e)
        return Event(id: "\(calendar.id)/\(e.id)", title: e.summary ?? "(No title)", start: start, end: end,
                     isAllDay: startTime.dateTime == nil,
                     calendar: calendar.primary == true && !namePrimary ? nil : calendar.summaryOverride ?? calendar.summary,
                     colorHex: e.colorId.flatMap { eventColors[$0] } ?? calendar.backgroundColor,
                     meetingURL: meeting.map { $0.url.host() == "meet.google.com" ? inAccount($0.url, account) : $0.url },
                     meetingName: meeting?.name,
                     link: e.htmlLink.flatMap { URL(string: $0) }.map { inAccount($0, account) },
                     isImportant: meeting != nil || (e.attendees?.count ?? 0) > 1)
    }

    /// `dateTime` for timed events; `date` (local midnight) for all-day ones.
    static func date(_ t: APIEvent.Time) -> Date? {
        if let s = t.dateTime { return ISO8601DateFormatter().date(from: s) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        return t.date.flatMap { f.date(from: $0) }
    }

    /// Conference data first (Meet, and add-ons like Zoom), then a known video link in the location or description.
    static func meetingLink(_ e: APIEvent) -> (url: URL, name: String)? {
        if let uri = e.conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" })?.uri,
           let url = URL(string: uri) {
            return (url, e.conferenceData?.conferenceSolution?.name ?? provider(url) ?? "Video call")
        }
        if let url = e.hangoutLink.flatMap({ URL(string: $0) }) { return (url, "Google Meet") }
        let text = [e.location, e.description].compactMap { $0 }.joined(separator: "\n")
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let url = match.url, let name = provider(url) { return (url, name) }
        }
        return nil
    }

    /// Google web links otherwise open in whichever account the browser signed in to first.
    static func inAccount(_ url: URL, _ account: String) -> URL {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        c.queryItems = (c.queryItems ?? []) + [URLQueryItem(name: "authuser", value: account)]
        return c.url ?? url
    }

    static func provider(_ url: URL) -> String? {
        guard let host = url.host()?.lowercased() else { return nil }
        return providers.first { host == $0.key || host.hasSuffix("." + $0.key) }?.value
    }

    private static func get<T: Decodable>(_ type: T.Type, _ path: String, _ query: [URLQueryItem], account: String) async throws -> T {
        let token = try await GoogleAuth.shared.accessToken(for: account)
        var c = URLComponents(string: "https://www.googleapis.com/calendar/v3/" + path)!
        if !query.isEmpty { c.queryItems = query }
        var request = URLRequest(url: c.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await googleSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 401 { await GoogleAuth.shared.dropAccessToken(for: account) }
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.error.message ?? "Google Calendar error \(status)."
            if message.contains("insufficient authentication scopes") { // signed in without ticking calendar access
                await GoogleAuth.shared.signOut(account)
                throw GoogleAuth.AuthError.noCalendarAccess(account)
            }
            throw AppError(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
