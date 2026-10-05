import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy policy – CalendarBar",
};

export default function Privacy() {
  return (
    <article className="mx-auto max-w-2xl px-6 py-12 [&_h2]:mt-10 [&_h2]:mb-3 [&_h2]:text-lg [&_h2]:font-semibold [&_li]:mt-2 [&_p]:mt-3 [&_p]:text-muted-foreground [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:text-muted-foreground">
      <h1 className="text-3xl font-semibold tracking-tight">Privacy policy</h1>
      <p>Last updated 5 October 2026.</p>
      <p>
        CalendarBar is a macOS menu bar app made by Kumpan Grafisk Form AB (&quot;Kumpan&quot;,
        &quot;we&quot;). It shows events from your Google Calendar. This policy explains what data
        the app accesses and what it does with it.
      </p>

      <h2>The short version</h2>
      <p>
        CalendarBar runs entirely on your Mac. It has no server and no analytics. Your calendar data
        goes from Google to your Mac and nowhere else.
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
          <code>calendar.events.readonly</code> scope): events for today and tomorrow, including
          titles, times, colours, video call links, locations, descriptions and guests&apos; response
          status.
        </li>
        <li>
          <strong>Your email address</strong> (the <code>openid</code> and <code>email</code>{" "}
          scopes), to tell your signed-in accounts apart.
        </li>
      </ul>
      <p>CalendarBar can&apos;t create, change or delete anything in your calendars.</p>

      <h2>How the data is used</h2>
      <ul>
        <li>To show your next event and your events for today and tomorrow in the menu bar.</li>
        <li>To open the video call or the event in Google Calendar when you click it.</li>
        <li>
          To show the Meeting Guardian alert before meetings that have a video link or other guests.
        </li>
      </ul>
      <p>The data is not used for advertising, profiling or any other purpose.</p>

      <h2>Storage</h2>
      <ul>
        <li>
          Calendar data is kept in the app&apos;s memory only, and is never written to disk. It is
          gone when the app quits.
        </li>
        <li>
          For each signed-in account, a Google refresh token is stored in your Mac&apos;s Keychain so
          you stay signed in. Your settings (such as the alert time) are stored in the app&apos;s
          preferences on your Mac.
        </li>
      </ul>

      <h2>Sharing</h2>
      <p>
        We don&apos;t receive, sell, transfer or share your Google data with anyone. The app only
        talks to Google, to load your calendars, and to GitHub, to check for new versions of the
        app. Update checks don&apos;t include any personal data.
      </p>

      <h2>Google API Services User Data Policy</h2>
      <p>
        CalendarBar&apos;s use and transfer of information received from Google APIs adheres to the{" "}
        <a
          href="https://developers.google.com/terms/api-services-user-data-policy"
          className="text-foreground underline underline-offset-4"
        >
          Google API Services User Data Policy
        </a>
        , including the Limited Use requirements.
      </p>

      <h2>Removing access</h2>
      <p>
        In CalendarBar, open Settings and click <strong>Remove</strong> next to an account. This
        deletes its token from your Keychain and revokes CalendarBar&apos;s access at Google. You can
        also revoke access at{" "}
        <a
          href="https://myaccount.google.com/permissions"
          className="text-foreground underline underline-offset-4"
        >
          myaccount.google.com/permissions
        </a>
        . Deleting the app removes everything else.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about this policy:{" "}
        <a href="mailto:per@kumpan.se" className="text-foreground underline underline-offset-4">
          per@kumpan.se
        </a>
        , Kumpan Grafisk Form AB, Industrigatan 4B, 112 46 Stockholm, Sweden.
      </p>
    </article>
  );
}
