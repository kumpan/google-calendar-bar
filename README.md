# CalendarBar

Your Google Calendar in the Mac menu bar. See what's next, join the call in one click, and get a
heads-up before meetings you can't miss.

**Website:** [calendarbar.kumpan.se](https://calendarbar.kumpan.se) · **Requires** macOS 26 or later, and a Google account (work or private, or both).

---

## Install

1. Download **`CalendarBar-<version>.zip`** from the
   **[latest release](https://github.com/kumpan/google-calendar-bar/releases/latest)** (under **Assets**).
2. Unzip it and drag **CalendarBar** into your **Applications** folder.
3. Open it. A calendar icon appears in the menu bar. The app is signed and notarized by Apple, so it opens
   without warnings.
4. Click the icon → **Sign in with Google** and allow CalendarBar to see your calendars. It only gets
   read access. If Google says it hasn't verified the app, click **Advanced** → **Go to CalendarBar**.
5. To add another account, such as your private one: Settings (⚙︎) → **Add Account…**.
6. Settings → **Open at login** so it's always running.

## Using it

- **The card at the top** shows the next event, or the one in progress. **Join** opens the video call
  (Google Meet, Zoom, Teams, Webex and more).
- **Today / Tomorrow** list every event. Click one to open it in Google Calendar; click the camera to join.
- CalendarBar shows the calendars that are ticked in each account's Google Calendar sidebar. Declined events
  are hidden, and a meeting that's on several of your calendars is shown once.

## Meeting Guardian

One minute before a meeting with a video link or other guests, a panel appears at the top of the screen
with a sound, also over full-screen apps. **Join** opens the call, **Snooze 5m** brings it back in five
minutes, **✕** dismisses it.

Turn it on or off by clicking **Meeting Guardian** in the menu. Settings has the alert time
(when it starts, or 1, 2 or 5 minutes before) and a **Preview** button.

## Updates

CalendarBar checks for new versions once a day. When one is available, **Update x.y.z** appears at
the bottom of the menu. Click it, then **Install and Relaunch**. You can also go to Settings →
**Check for Updates**. Updates are only installed if they are signed by Kumpan and notarized by Apple.

## Troubleshooting

| Problem | Fix |
|---|---|
| "… was signed out" | Settings → **Add Account…** and sign in to that account again. This happens if you revoke access or change your Google password. |
| An event is missing | Make sure its calendar is ticked in Google Calendar's sidebar, then click ↻. |
| No Join button | The event has no video link in its conference details, location or description. |
| Repeated Keychain password prompts | Click **Always Allow**. |

## Privacy

- CalendarBar talks only to Google (read-only calendar access) and GitHub (update checks).
- Each Google sign-in is stored as a refresh token in your Mac's Keychain. **Remove** in Settings deletes it
  and revokes it at Google.

---

<details>
<summary><b>For developers</b></summary>

```sh
swift test                  # unit tests
./build.sh                  # → dist/CalendarBar.app (Developer ID-signed if the cert is installed, else ad-hoc)
./build.sh release          # also notarizes + staples → dist/CalendarBar-<VERSION>.zip
swift scripts/make-icon.swift preview out.png   # icon preview; `swift scripts/make-icon.swift` writes Resources/AppIcon.icns
```

- **Releases:** every push to `main` that isn't docs-only runs `.github/workflows/release.yml`: tests,
  build, Developer ID signing, notarization, and a GitHub release `v<VERSION>.<run number>`. Edit
  `VERSION` to bump the major/minor version. The workflow header lists the four secrets it needs (the same
  ones as PassboltBar). The repo must stay public: the updater reads releases without a token.
- **Local releases** need Kumpan's *Developer ID Application* certificate in the login keychain and a
  notarytool profile:
  `xcrun notarytool store-credentials CalendarBar --apple-id <apple id> --team-id NH4M8452G6`.
- **Website** (`web/`): Next.js + shadcn/ui. The homepage and `/privacy` are what Google's OAuth
  verification checks, at calendarbar.kumpan.se. Host it with base directory `web`, build `npm run build`,
  start `npm start` (port 3000). `npm --prefix web run dev` for local work.
- **Google OAuth client:** `GoogleAuth.clientID` is an OAuth client of type **iOS** (bundle id
  `se.kumpan.calendarbar`) in Google Cloud project `plasma-ember-510706-f6`, with the Google Calendar API
  enabled. An iOS client needs no client secret, so the ID is safe to commit. Sign-in is PKCE through
  `ASWebAuthenticationSession` with the reversed client ID as callback scheme. Scopes: `openid email
  calendar.calendarlist.readonly calendar.events.readonly` (the narrowest read-only scopes for
  the calendar list and events); the email in the ID token keys each account's refresh token in the keychain.
- **Consent screen:** audience **External** so private Gmail accounts work, publishing status **In
  production** (in *Testing*, refresh tokens expire after 7 days). The calendar scopes are sensitive,
  so until Google verifies the app, sign-in shows an "unverified app" warning and is capped at 100 users.
  Verification needs a homepage and privacy policy on a domain the project owns.
- **Implementation notes:**
  - Events are fetched for today and tomorrow every 5 minutes, and when the menu opens if they're over a
    minute old. A shared event on several selected calendars is shown once (the primary calendar's copy).
  - The Meeting Guardian panel is a non-activating `NSPanel` that never becomes key, so it doesn't steal
    typing focus. Because of that, AppKit draws its controls inactive; the view forces the key appearance,
    and Join uses a solid fill since glass tints still turn grey.
  - The updater verifies the code signature requirement (team `NH4M8452G6`, id `se.kumpan.calendarbar`)
    and `spctl` notarization before swapping the bundle.

</details>
