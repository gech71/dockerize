"use client";

import Image from "next/image";
import { simpleServerAction } from "./actions";
import { useState } from "react";
import Link from "next/link";

export default function Home() {
  const [serverMessage, setServerMessage] = useState("");
  const [routeMessage, setRouteMessage] = useState("");

  async function handleServerAction() {
    const message = await simpleServerAction();
    setServerMessage(message);
  }

  const handleRouteHandler = async () => {
    const result = await fetch("/api/hello");
    const data = await result.json();
    setRouteMessage(data.message);
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-zinc-100 to-zinc-200 dark:from-zinc-950 dark:to-black px-4">
      <main className="w-full max-w-xl rounded-2xl bg-white dark:bg-zinc-900 shadow-xl p-10 space-y-8">
        {/* Logo */}
        <div className="flex justify-center">
          <Image
            className="dark:invert"
            src="/next.svg"
            alt="Next.js logo"
            width={110}
            height={24}
            priority
          />
        </div>

        {/* Title */}
        <div className="text-center space-y-2">
          <h1 className="text-3xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100">
            Next.js App Router Demo
          </h1>
          <p className="text-zinc-600 dark:text-zinc-400">
            Edit <code className="font-mono text-sm">page.tsx</code> to get
            started
          </p>
        </div>

        {/* Actions */}
        <div className="space-y-4">
          <button
            onClick={handleServerAction}
            className="w-full rounded-lg bg-blue-600 px-4 py-2.5 text-white font-medium transition hover:bg-blue-700 active:scale-[0.98]"
          >
            Call Server Action
          </button>

          {serverMessage && (
            <div className="rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-700 dark:border-green-800 dark:bg-green-900/30 dark:text-green-300">
              {serverMessage}
            </div>
          )}

          <button
            onClick={handleRouteHandler}
            className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-white font-medium transition hover:bg-indigo-700 active:scale-[0.98]"
          >
            Call Route Handler Updated
          </button>

          {routeMessage && (
            <div className="rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-700 dark:border-green-800 dark:bg-green-900/30 dark:text-green-300">
              {routeMessage}
            </div>
          )}
        </div>

        {/* Navigation */}
        <div className="text-center">
          <Link
            href="/about"
            className="inline-flex items-center gap-1 text-blue-600 dark:text-blue-400 font-medium hover:underline"
          >
            Go to About Page →
          </Link>
        </div>
      </main>
    </div>
  );
}
