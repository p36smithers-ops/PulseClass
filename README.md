# PulseClass

PulseClass is a mobile-first teaching and sports-science platform for classroom heart-rate monitoring.

## Current build

This repository starts the Expo application for iOS, Android and web. The first screen set includes:
- Teacher dashboard
- Class management starter
- Live lesson monitoring starter
- Student lesson-join experience

The current screens are an initial interface foundation. They do not yet write to Supabase or collect real heart-rate data.

## Technology

- Expo SDK 58
- React Native 0.88
- TypeScript
- Supabase (connection to be configured through environment variables)

## Getting started

Use Node.js 22.13 or newer.

```bash
npm install
npx expo start
```

For the web preview:

```bash
npx expo start --web
```

## Supabase setup

Copy `.env.example` to `.env` and add the project URL and **publishable client key**.

Never put a Supabase service-role key or database password in this app. Privileged operations will be handled server-side.

## Important architecture notes

- There is one teacher account.
- Students join a lesson using a display name and a class join code; they do not create Supabase Auth accounts.
- Student access should use short-lived, server-validated lesson tokens.
- Existing Supabase tables and policies must be baselined and reviewed before any migration is applied.
- Real heart-rate integrations require a supported wearable/device integration and permission testing.

## Status

Early scaffold — not production-ready. Supabase integration, secure student joining, live data, tests and deployment remain to be implemented.
