import XCTest
@testable import CalendarBar

final class CalendarBarTests: XCTestCase {
    let primary = GoogleCalendar.Entry(id: "me@kumpan.se", summary: "me@kumpan.se", summaryOverride: nil,
                                       backgroundColor: "#9fe1e7", selected: true, primary: true)
    let work = GoogleCalendar.Entry(id: "work#x@group.calendar.google.com", summary: "Work", summaryOverride: "Work – Meetings",
                                    backgroundColor: "#4285f4", selected: true, primary: false)

    func decode(_ json: String) throws -> [GoogleCalendar.APIEvent] {
        try JSONDecoder().decode(GoogleCalendar.EventList.self, from: Data(json.utf8)).items
    }

    func testMapsEvents() throws {
        let items = try decode(#"""
        {"items": [
          {"id": "a", "summary": "Daily standup", "colorId": "3",
           "start": {"dateTime": "2026-10-05T16:30:00+02:00"}, "end": {"dateTime": "2026-10-05T17:00:00+02:00"},
           "hangoutLink": "https://meet.google.com/abc-defg-hij",
           "conferenceData": {"conferenceSolution": {"name": "Google Meet"}, "entryPoints": [
             {"entryPointType": "phone", "uri": "tel:+46-8-123"},
             {"entryPointType": "video", "uri": "https://meet.google.com/abc-defg-hij"}]},
           "attendees": [{"email": "me@kumpan.se", "self": true, "responseStatus": "accepted"}, {"email": "b@kumpan.se"}]},
          {"id": "b", "summary": "Vacation", "start": {"date": "2026-10-05"}, "end": {"date": "2026-10-06"}},
          {"id": "c", "summary": "Declined", "start": {"dateTime": "2026-10-05T08:00:00Z"}, "end": {"dateTime": "2026-10-05T09:00:00Z"},
           "attendees": [{"self": true, "responseStatus": "declined"}, {"email": "x@y.se"}]},
          {"id": "d", "summary": "Client call", "location": "Room 1",
           "description": "Join: <a href=\"https://us02web.zoom.us/j/123?pwd=abc\">here</a>",
           "start": {"dateTime": "2026-10-05T10:00:00Z"}, "end": {"dateTime": "2026-10-05T11:00:00Z"}},
          {"id": "e", "eventType": "workingLocation", "start": {"date": "2026-10-05"}, "end": {"date": "2026-10-06"}},
          {"id": "f", "summary": "Gym", "start": {"dateTime": "2026-10-05T18:00:00+02:00"}, "end": {"dateTime": "2026-10-05T19:00:00+02:00"}}
        ]}
        """#)
        let events = items.compactMap { GoogleCalendar.makeEvent($0, calendar: work) }
        XCTAssertEqual(events.map(\.title), ["Daily standup", "Vacation", "Client call", "Gym"])

        let standup = events[0]
        XCTAssertEqual(standup.meetingURL?.absoluteString, "https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(standup.meetingName, "Google Meet")
        XCTAssertEqual(standup.colorHex, "#8E24AA")
        XCTAssertEqual(standup.calendar, "Work – Meetings")
        XCTAssertTrue(standup.isImportant)
        XCTAssertEqual(standup.end.timeIntervalSince(standup.start), 1800)

        let vacation = events[1]
        XCTAssertTrue(vacation.isAllDay)
        XCTAssertEqual(vacation.start, Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5)))
        XCTAssertEqual(vacation.colorHex, "#4285f4")

        XCTAssertEqual(events[2].meetingURL?.absoluteString, "https://us02web.zoom.us/j/123?pwd=abc")
        XCTAssertEqual(events[2].meetingName, "Zoom")
        XCTAssertFalse(events[3].isImportant)
        XCTAssertNil(GoogleCalendar.makeEvent(items[0], calendar: primary)?.calendar)
        XCTAssertEqual(GoogleCalendar.makeEvent(items[0], calendar: primary, namePrimary: true)?.calendar, "me@kumpan.se")
    }

    func testFeaturedEvent() {
        func event(_ id: String, _ start: TimeInterval, _ end: TimeInterval, allDay: Bool = false) -> Event {
            Event(id: id, title: id, start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end),
                  isAllDay: allDay, calendar: nil, colorHex: nil, meetingURL: nil, meetingName: nil, link: nil, isImportant: true)
        }
        let events = [event("allday", 0, 100_000, allDay: true), event("done", 0, 900), event("ongoing", 1000, 5000),
                      event("soon", 2500, 4000), event("later", 9000, 9900)]
        func featured(_ now: TimeInterval) -> String? { featuredEvent(events, now: Date(timeIntervalSince1970: now))?.id }
        XCTAssertEqual(featured(300), "done")
        XCTAssertEqual(featured(1200), "ongoing")      // "soon" is more than 10 minutes away
        XCTAssertEqual(featured(2000), "soon")         // within 10 minutes: beats the one in progress
        XCTAssertEqual(featured(4500), "ongoing")
        XCTAssertEqual(featured(6000), "later")
        XCTAssertNil(featured(10_000))
    }

    func testEmailFromIDToken() {
        // Header and signature don't matter; payload {"email":"per@gmail.com","sub":"1"} in base64url without padding.
        let payload = Data(#"{"email":"per@gmail.com","sub":"1"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        XCTAssertEqual(GoogleAuth.email(fromIDToken: "eyJhbGciOiJSUzI1NiJ9.\(payload).sig"), "per@gmail.com")
        XCTAssertNil(GoogleAuth.email(fromIDToken: "garbage"))
    }

    func testDuration() {
        XCTAssertEqual(duration(10), "1m")
        XCTAssertEqual(duration(45 * 60), "45m")
        XCTAssertEqual(duration(3600), "1h")
        XCTAssertEqual(duration(91 * 60 - 20), "1h 31m")
    }

    func testVersionComparison() {
        XCTAssertTrue(Updater.isVersion("1.0.10", newerThan: "1.0.9"))
        XCTAssertFalse(Updater.isVersion("1.0", newerThan: "1.0.0"))
    }
}
