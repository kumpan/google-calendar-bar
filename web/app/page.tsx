import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Download, Sparkle } from "lucide-react";

const download = "https://github.com/kumpan/google-calendar-bar/releases/latest/download/CalendarBar.dmg";

const highlights = [
  {
    title: "Join in one click",
    text: "The next meeting sits at the top of the menu, with its video link one click away.",
    points: ["Google Meet, Zoom, Microsoft Teams and Webex", "Opens in the right Google account", "Today and tomorrow at a glance"],
    // Kumpan's quarter-circle corner, as on kumpan.se
    className: "bg-lavender text-kumpan rounded-br-[7rem]",
    pointClass: "border-kumpan/15",
  },
  {
    title: "Meeting Guardian",
    text: "A hard-to-miss alert just before meetings with a video link or other guests.",
    points: ["Join or snooze for five minutes", "Shows over full-screen apps", "Alert when it starts, or 1, 2 or 5 minutes before"],
    className: "bg-card text-card-foreground rounded-tr-[7rem]",
    pointClass: "border-black/10",
  },
];

const features = [
  { title: "Work and private", text: "Add several Google and Microsoft accounts. A meeting that’s on more than one of your Google calendars shows once." },
  { title: "Your calendars, your colours", text: "CalendarBar shows the calendars ticked in Google Calendar’s sidebar and your Outlook calendars, each in its own colour." },
  { title: "Keeps itself up to date", text: "New versions install in two clicks, and only if they’re signed by Kumpan and notarized by Apple." },
];

export default function Home() {
  return (
    <>
      <div className="mx-auto max-w-6xl px-6">
        <section className="grid items-center gap-14 py-14 md:grid-cols-[1fr_auto] md:py-24">
          <div className="max-w-2xl">
            <h1 className="text-5xl leading-[1.05] tracking-tight text-balance sm:text-6xl">
              Your calendar in the Mac menu bar.
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground text-pretty">
              Google Calendar and Outlook, side by side. See what&apos;s next, join the call in one
              click, and get a heads-up before meetings you can&apos;t miss. Free, from Kumpan.
            </p>
            <div className="mt-10 flex flex-wrap items-center gap-x-5 gap-y-3">
              <a
                href={download}
                className="inline-flex h-12 items-center gap-2.5 rounded-full bg-lavender px-6 font-medium text-kumpan transition-colors hover:bg-white focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
              >
                <Download className="size-5" />
                Download for Mac
              </a>
              <span className="text-sm text-muted-foreground">
                Open it and drag CalendarBar into Applications. macOS 26 or later.
              </span>
            </div>
          </div>
          <Image
            src="/panel.png"
            alt="CalendarBar's menu showing the next meeting with a Join button, and today's and tomorrow's events"
            width={360}
            height={495}
            priority
            className="mx-auto rounded-[26px] shadow-2xl shadow-black/60"
          />
        </section>

        <section className="grid gap-3 md:grid-cols-2">
          {highlights.map((h) => (
            <div key={h.title} className={`rounded-3xl p-8 sm:p-10 ${h.className}`}>
              <h2 className="text-4xl tracking-tight">{h.title}</h2>
              <p className="mt-5 max-w-md leading-relaxed opacity-80">{h.text}</p>
              <ul className="mt-8 text-sm">
                {h.points.map((p) => (
                  <li key={p} className={`border-t py-3 first:border-t-0 ${h.pointClass}`}>
                    {p}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </section>

        <section className="grid gap-12 py-24 md:grid-cols-[1fr_1.1fr]">
          <h2 className="text-4xl leading-tight tracking-tight text-balance">
            Built for the way you already work.
          </h2>
          <ul>
            {features.map((f) => (
              <li key={f.title} className="border-t border-border py-7 last:border-b">
                <h3 className="text-2xl tracking-tight">{f.title}</h3>
                <p className="mt-2 max-w-md leading-relaxed text-muted-foreground">{f.text}</p>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="mx-3 rounded-[2rem] bg-kumpan px-6 py-20 sm:mx-6 md:py-24">
        <div className="mx-auto grid max-w-6xl items-end gap-10 md:grid-cols-[1.3fr_1fr]">
          <div>
            <Sparkle className="size-12 fill-white text-white" strokeWidth={1} />
            <h2 className="mt-8 text-4xl leading-[1.08] tracking-tight text-balance sm:text-5xl">
              Read-only. Your calendar never leaves your Mac.
            </h2>
          </div>
          <div>
            <p className="leading-relaxed text-white/80">
              When you sign in, CalendarBar asks Google or Microsoft for read-only access to your
              calendars and events, and for your email address to tell accounts apart. It has no
              server, and your calendar data is never sent to Kumpan or anyone else.
            </p>
            <Link
              href="/privacy"
              className="mt-6 inline-flex h-11 items-center gap-2 rounded-full bg-white px-5 text-sm font-medium text-black transition-colors hover:bg-lavender"
            >
              Privacy policy
              <ArrowRight className="size-4" />
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
