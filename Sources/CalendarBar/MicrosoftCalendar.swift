import Foundation

/// Read-only Microsoft Graph client for Outlook and Microsoft 365 calendars.
enum MicrosoftCalendar {
    struct CalendarList: Decodable { let value: [Entry] }
    struct Entry: Decodable {
        let id: String
        let name: String?
        let hexColor: String?
        let isDefaultCalendar: Bool?
    }

    struct EventList: Decodable { let value: [APIEvent] }
    struct APIEvent: Decodable {
        struct Time: Decodable { let dateTime: String }
        struct Response: Decodable { let response: String? }
        struct OnlineMeeting: Decodable { let joinUrl: String? }
        struct Location: Decodable { let displayName: String? }
        struct Body: Decodable { let content: String? }
        struct Attendee: Decodable {}
        let id: String
        let iCalUId: String?
        let subject: String?
        let start: Time
        let end: Time
        let isAllDay: Bool?
        let isCancelled: Bool?
        let webLink: String?
        let onlineMeeting: OnlineMeeting?
        let onlineMeetingProvider: String?
        let location: Location?
        let body: Body?
        let attendees: [Attendee]?
        let responseStatus: Response?
    }

    /// Times in UTC and plain-text bodies, so links can be found in them.
    static let headers = ["Prefer": #"outlook.timezone="UTC", outlook.body-content-type="text""#]

    /// Events on every calendar in each account's Outlook. Graph has no "shown in the sidebar" flag like
    /// Google's, so all of the account's own calendars are read.
    static func events(accounts: [String], from start: Date, to end: Date, namePrimary: Bool) async throws -> [Event] {
        var calendars: [(account: String, entry: Entry)] = []
        for account in accounts {
            let url = URL(string: "https://graph.microsoft.com/v1.0/me/calendars?$select=id,name,hexColor,isDefaultCalendar")!
            calendars += try await apiGet(CalendarList.self, url, account: account).value
                .sorted { $0.isDefaultCalendar == true && $1.isDefaultCalendar != true }
                .map { (account, $0) }
        }
        let iso = ISO8601DateFormatter()
        let lists = try await withThrowingTaskGroup(of: (Int, [APIEvent]).self) { group in
            for (i, calendar) in calendars.enumerated() {
                let id = calendar.entry.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/")))!
                var c = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(id)/calendarView")!
                c.queryItems = [
                    URLQueryItem(name: "startDateTime", value: iso.string(from: start)),
                    URLQueryItem(name: "endDateTime", value: iso.string(from: end)),
                    URLQueryItem(name: "$top", value: "250"), // ponytail: no paging, like the Google client
                    URLQueryItem(name: "$select", value: "id,iCalUId,subject,start,end,isAllDay,isCancelled,webLink,onlineMeeting,onlineMeetingProvider,location,body,attendees,responseStatus"),
                ]
                group.addTask { (i, try await apiGet(EventList.self, c.url!, account: calendar.account, headers: headers).value) }
            }
            return try await group.reduce(into: [Int: [APIEvent]]()) { $0[$1.0] = $1.1 }
        }
        var seen = Set<String>()
        return calendars.indices.flatMap { i in
            (lists[i] ?? [])
                .filter { seen.insert("\($0.iCalUId ?? $0.id)|\($0.start.dateTime)").inserted }
                .compactMap { makeEvent($0, calendar: calendars[i].entry, account: calendars[i].account, namePrimary: namePrimary) }
        }
    }

    /// The default calendar ("Calendar") goes unnamed, or shows the account when there are several.
    static func makeEvent(_ e: APIEvent, calendar: Entry, account: String, namePrimary: Bool = false) -> Event? {
        let allDay = e.isAllDay == true
        guard e.isCancelled != true, e.responseStatus?.response != "declined",
              let start = date(e.start, allDay: allDay), let end = date(e.end, allDay: allDay) else { return nil }
        let meeting = meetingLink(e)
        let calendarName = calendar.isDefaultCalendar == true ? (namePrimary ? AccountKey.email(account) : nil) : calendar.name
        return Event(id: "\(account)/\(e.id)", title: e.subject.flatMap { $0.isEmpty ? nil : $0 } ?? "(No title)",
                     start: start, end: end, isAllDay: allDay, calendar: calendarName,
                     colorHex: calendar.hexColor.flatMap { $0.isEmpty ? nil : $0 },
                     meetingURL: meeting?.url, meetingName: meeting?.name,
                     link: e.webLink.flatMap { URL(string: $0) },
                     isImportant: meeting != nil || !(e.attendees ?? []).isEmpty)
    }

    /// Graph's "2026-10-06T14:30:00.0000000" in UTC. An all-day event is midnight in whatever zone it was
    /// made in, so its day is the local midnight nearest to that instant.
    static func date(_ t: APIEvent.Time, allDay: Bool) -> Date? {
        guard let utc = ISO8601DateFormatter().date(from: String(t.dateTime.prefix(19)) + "Z") else { return nil }
        return allDay ? Calendar.current.startOfDay(for: utc.addingTimeInterval(12 * 3600)) : utc
    }

    /// The Teams (or other) online meeting first, then a known video link in the location or body.
    static func meetingLink(_ e: APIEvent) -> (url: URL, name: String)? {
        if let url = e.onlineMeeting?.joinUrl.flatMap({ URL(string: $0) }) {
            return (url, VideoLink.provider(url) ?? (e.onlineMeetingProvider == "teamsForBusiness" ? "Microsoft Teams" : "Video call"))
        }
        return VideoLink.find(in: [e.location?.displayName, e.body?.content].compactMap { $0 }.joined(separator: "\n"))
    }
}
