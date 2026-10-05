import Image from "next/image";
import Link from "next/link";
import { Bell, CalendarClock, Download, Lock, Users, Video } from "lucide-react";
import { buttonVariants } from "@/components/ui/button";

const features = [
  {
    icon: CalendarClock,
    title: "What's next, at a glance",
    text: "Your next meeting, today's and tomorrow's events, in your calendars' own colours.",
  },
  {
    icon: Video,
    title: "Join in one click",
    text: "Google Meet, Zoom, Microsoft Teams, Webex and more, straight from the menu bar.",
  },
  {
    icon: Bell,
    title: "Meeting Guardian",
    text: "A hard-to-miss alert just before meetings with a video link or other guests. Join or snooze.",
  },
  {
    icon: Users,
    title: "Work and private",
    text: "Add several Google accounts. A meeting that's on more than one calendar is shown once.",
  },
];

export default function Home() {
  return (
    <div className="mx-auto max-w-5xl px-6">
      <section className="grid items-center gap-12 py-12 md:grid-cols-[1fr_auto] md:py-20">
        <div className="max-w-xl">
          <h1 className="text-4xl font-semibold tracking-tight text-balance sm:text-5xl">
            Your Google Calendar in the Mac menu bar.
          </h1>
          <p className="mt-5 text-lg text-muted-foreground text-pretty">
            See what&apos;s next, join the call in one click, and get a heads-up before meetings you
            can&apos;t miss. Free, from Kumpan.
          </p>
          <div className="mt-8 flex flex-wrap items-center gap-4">
            <a
              href="https://github.com/kumpan/google-calendar-bar/releases/latest"
              className={buttonVariants({ size: "lg", className: "h-11 px-5 text-base" })}
            >
              <Download />
              Download for Mac
            </a>
            <span className="text-sm text-muted-foreground">
              macOS 26 or later · Signed and notarized by Apple
            </span>
          </div>
        </div>
        <Image
          src="/panel.png"
          alt="CalendarBar's menu showing the next meeting with a Join button, and today's and tomorrow's events"
          width={360}
          height={495}
          priority
          className="mx-auto rounded-[26px] shadow-2xl"
        />
      </section>

      <section className="grid gap-x-10 gap-y-8 border-t py-14 sm:grid-cols-2">
        {features.map(({ icon: Icon, title, text }) => (
          <div key={title} className="flex gap-4">
            <Icon className="mt-0.5 size-5 shrink-0 text-primary" />
            <div>
              <h2 className="font-medium">{title}</h2>
              <p className="mt-1 text-muted-foreground">{text}</p>
            </div>
          </div>
        ))}
      </section>

      <section className="flex gap-4 border-t py-14">
        <Lock className="mt-0.5 size-5 shrink-0 text-primary" />
        <div className="max-w-2xl">
          <h2 className="font-medium">How CalendarBar uses your Google data</h2>
          <p className="mt-1 text-muted-foreground">
            When you sign in, CalendarBar asks Google for read-only access to your calendars and for
            your email address. It uses them only to show your events and to tell your accounts apart.
            Everything stays on your Mac: CalendarBar has no server, and your calendar data is never
            sent to Kumpan or anyone else. Read the{" "}
            <Link href="/privacy" className="text-foreground underline underline-offset-4">
              privacy policy
            </Link>
            .
          </p>
        </div>
      </section>
    </div>
  );
}
