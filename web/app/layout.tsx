import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Zalando_Sans_SemiExpanded } from "next/font/google";
import "./globals.css";

// The kumpan.se typeface.
const zalando = Zalando_Sans_SemiExpanded({
  variable: "--font-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "CalendarBar – your calendar in the Mac menu bar",
  description:
    "See what's next, join video calls in one click and get a heads-up before meetings. A free menu bar app for Google Calendar by Kumpan.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${zalando.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col">
        <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-6">
          <Link href="/" className="flex items-center gap-2.5 font-medium">
            <Image src="/logo.png" alt="" width={32} height={32} />
            CalendarBar
          </Link>
          <nav className="flex gap-6 text-sm text-muted-foreground">
            <Link href="/privacy" className="hover:text-foreground">
              Privacy
            </Link>
            <a href="https://github.com/kumpan/google-calendar-bar" className="hover:text-foreground">
              GitHub
            </a>
          </nav>
        </header>
        <main className="flex-1">{children}</main>
        <footer className="mx-auto w-full max-w-6xl px-6 py-10 text-sm text-muted-foreground">
          © {new Date().getFullYear()} Kumpan Sweden AB ·{" "}
          <Link href="/privacy" className="underline-offset-4 hover:underline">
            Privacy policy
          </Link>{" "}
          ·{" "}
          <a href="mailto:per@kumpan.se" className="underline-offset-4 hover:underline">
            per@kumpan.se
          </a>
        </footer>
      </body>
    </html>
  );
}
