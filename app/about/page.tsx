"use client";

import Link from "next/link";

export default function AboutPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-zinc-100 to-zinc-200 dark:from-zinc-950 dark:to-black px-4">
      <main className="w-full max-w-xl rounded-2xl bg-white dark:bg-zinc-900 shadow-xl p-10 space-y-6">
        <div className="space-y-2">
          <h1 className="text-3xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100">
            About Page
          </h1>
          <p className="text-zinc-600 dark:text-zinc-400">
            This is a secondary page in your Next.js App Router demo.
          </p>
        </div>

        <div className="border-t border-zinc-200 dark:border-zinc-800 pt-4">
          <Link
            href="/"
            className="inline-flex items-center gap-1 text-blue-600 dark:text-blue-400 font-medium hover:underline"
          >
            ← Back to Home
          </Link>
        </div>
      </main>
    </div>
  );
}
