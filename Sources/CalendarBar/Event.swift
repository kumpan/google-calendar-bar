import Foundation

/// A calendar event from any provider, as the app shows it.
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
    /// The event in Google Calendar or Outlook on the web.
    let link: URL?
    /// Has a video link or other guests. The Meeting Guardian only alerts for these.
    let isImportant: Bool
}

/// Video call links: which service a URL belongs to, and the first one in free text.
enum VideoLink {
    static let providers = ["meet.google.com": "Google Meet", "zoom.us": "Zoom", "teams.microsoft.com": "Microsoft Teams",
                            "teams.live.com": "Microsoft Teams", "webex.com": "Webex", "whereby.com": "Whereby",
                            "chime.aws": "Amazon Chime", "gotomeeting.com": "GoTo Meeting"]

    static func provider(_ url: URL) -> String? {
        guard let host = url.host()?.lowercased() else { return nil }
        return providers.first { host == $0.key || host.hasSuffix("." + $0.key) }?.value
    }

    /// The first known video link in an event's location or description.
    static func find(in text: String) -> (url: URL, name: String)? {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let url = match.url, let name = provider(url) { return (url, name) }
        }
        return nil
    }
}
