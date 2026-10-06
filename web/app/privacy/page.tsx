import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy policy – CalendarBar",
};

const link = "text-foreground underline underline-offset-4";

export default function Privacy() {
  return (
    <article className="mx-auto max-w-2xl px-6 py-12 [&_h2]:mt-10 [&_h2]:mb-3 [&_h2]:text-lg [&_h2]:font-semibold [&_li]:mt-2 [&_p]:mt-3 [&_p]:text-muted-foreground [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:text-muted-foreground">
      <h1 className="text-3xl font-semibold tracking-tight">Privacy policy</h1>
      <p>Last updated 6 October 2026.</p>
      <p>
        CalendarBar is a macOS menu bar app made by Kumpan Sweden AB (&quot;Kumpan&quot;,
        &quot;we&quot;). It shows events from your Google Calendar. This policy explains what Google
        user data the app accesses, how it uses, shares, protects and deletes that data.
      </p>

      <h2>The short version</h2>
      <p>
        CalendarBar runs entirely on your Mac. It has no server, no analytics and no AI features.
        Your calendar data goes from Google to your Mac and nowhere else, and Kumpan never receives
        it.
      </p>

      <h2>Data the app accesses</h2>
      <p>When you sign in with a Google account, you grant CalendarBar:</p>
      <ul>
        <li>
          <strong>Read-only access to your calendar list</strong> (the{" "}
          <code>calendar.calendarlist.readonly</code> scope): the calendars you subscribe to, their
          names and colours, and which ones you show in Google Calendar.
        </li>
        <li>
          <strong>Read-only access to your events</strong> (the{" "}
          <code>calendar.events.readonly</code> scope): events for today and tomorrow on those
          calendars, including titles, times, colours, video call links, locations, descriptions
          and guests&apos; response status.
        </li>
        <li>
          <strong>Your email address</strong> (the <code>openid</code> and <code>email</code>{" "}
          scopes), to tell your signed-in accounts apart.
        </li>
      </ul>
      <p>
        CalendarBar can&apos;t create, change or delete anything in your calendars. It doesn&apos;t
        create aggregated or anonymized data from Google user data.
      </p>

      <h2>How the data is used</h2>
      <ul>
        <li>To show your next event and your events for today and tomorrow in the menu bar.</li>
        <li>To show each event in its calendar&apos;s colour and with its calendar&apos;s name.</li>
        <li>To open the video call or the event in Google Calendar when you click it.</li>
        <li>
          To show the Meeting Guardian alert before meetings that have a video link or other guests.
        </li>
      </ul>
      <p>
        Google user data is used only to provide these features. It is not used for advertising,
        profiling, credit or lending decisions, or any other purpose, and it is not used to develop,
        improve or train AI or machine learning models.
      </p>

      <h2>Sharing and transfer</h2>
      <p>
        We don&apos;t receive, sell, transfer or share Google user data with anyone, including
        advertisers, data brokers and AI or machine learning services. The app talks directly to
        Google to load your calendars, and to GitHub to check for new versions of the app. Update
        checks don&apos;t include any personal data.
      </p>

      <h2>How the data is protected</h2>
      <ul>
        <li>
          Sign-in uses Google&apos;s OAuth 2.0 with PKCE in Google&apos;s own sign-in page.
          CalendarBar never sees your Google password.
        </li>
        <li>All requests to Google are encrypted in transit with HTTPS (TLS).</li>
        <li>
          Calendar data and short-lived access tokens are kept only in the app&apos;s memory and
          are never written to disk, not even to a cache.
        </li>
        <li>
          The refresh token that keeps you signed in is stored in your Mac&apos;s Keychain, which
          macOS encrypts and protects with access controls: other apps can&apos;t read it without
          your permission.
        </li>
        <li>
          There is no server, so no copy of your data exists outside your Mac.
        </li>
        <li>
          The app is signed by Kumpan and notarized by Apple. Updates are installed only after
          their signature and notarization have been verified.
        </li>
      </ul>

      <h2>Retention and deletion</h2>
      <ul>
        <li>
          Calendar data is replaced on every refresh (every few minutes) and discarded when you
          quit the app or remove the account.
        </li>
        <li>
          A signed-in account&apos;s refresh token and email address stay in your Keychain until you
          remove the account. In CalendarBar, open Settings and click <strong>Remove</strong> next
          to the account: this deletes them and revokes CalendarBar&apos;s access at Google. If you
          revoke access at{" "}
          <a href="https://myaccount.google.com/permissions" className={link}>
            myaccount.google.com/permissions
          </a>{" "}
          instead, the app deletes the token the next time it tries to use it.
        </li>
        <li>
          Your settings, such as the alert time, are stored in the app&apos;s preferences on your
          Mac and are deleted with the app.
        </li>
        <li>
          Kumpan holds no Google user data, so there is nothing for us to delete on your behalf.
        </li>
      </ul>

      <h2>Google API Services User Data Policy</h2>
      <p>
        CalendarBar&apos;s use and transfer of information received from Google APIs adheres to the{" "}
        <a href="https://developers.google.com/terms/api-services-user-data-policy" className={link}>
          Google API Services User Data Policy
        </a>
        , including the Limited Use requirements.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about this policy:{" "}
        <a href="mailto:per@kumpan.se" className={link}>
          per@kumpan.se
        </a>
        , Kumpan Sweden AB, Industrigatan 4B, 112 46 Stockholm, Sweden.
      </p>
    </article>
  );
}
