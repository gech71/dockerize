"use client";

import Link from "next/link";

export default function AboutPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 font-sans dark:bg-black">
      <main className="flex w-full max-w-3xl flex-col items-center justify-between py-32 px-16 bg-white dark:bg-black sm:items-start">
        <div className="p-8">
          <h1 className="text-2xl font-bold">About Page</h1>
          <p>This is a second page.</p>
          <Link href="/" className="text-blue-600 underline">
            Go back to Home
          </Link>
        </div>
      </main>
    </div>
  );
}
