---
layout: default
title: Privacy Policy
---

# Privacy Policy — My Maxpster

_Last updated: June 7, 2026_

My Maxpster ("the app", "we") is a personal place-management iOS app developed by Max Leclercq. This page describes what data the app collects, where it lives, and who can see it.

## TL;DR

- **All your data stays in your iCloud account.** We have no server.
- **No analytics, no ads, no tracking.**
- **No third-party SDKs** are bundled in the app.
- Optional integrations (Yelp) only run when you turn them on, and only send the minimum data needed.

## What data the app handles

| Data | Where it lives | Who can see it |
|---|---|---|
| Places you save (name, address, coordinates, notes, rating, visit status, tags, collections, photos) | SwiftData on your device, mirrored to your private iCloud database | Only you, via your Apple ID |
| Your current location (when you tap "go to my location" or long-press the map to add a place) | Used in-memory to center the map / reverse-geocode an address. Not persisted. | Only the app on your device |
| Photos you attach to a place | App's local Application Support directory | Only you. Photos do not currently sync via iCloud — they remain on the device they were added to. |
| Your Yelp Fusion API key (if you set one up) | iOS Keychain on your device | Only you. Never bundled in source code. |

## What we do NOT collect

- We do **not** have an account system. There is no sign-up, no email/password, no user identifier.
- We do **not** use third-party analytics (no Firebase, no Sentry, no Crashlytics, no Mixpanel).
- We do **not** display ads.
- We do **not** track you across apps or websites.
- We do **not** receive any of your data. The app developer cannot see your saved places.

## When the app makes network requests

| Why | Where | When |
|---|---|---|
| Map tiles | Apple Maps servers | When the map is visible |
| Reverse geocoding (turn a coordinate into an address) | Apple's MapKit | When you long-press the map to add a place |
| Search suggestions ("Search Apple Maps") | Apple's MKLocalSearchCompleter | When you type into the map search bar |
| iCloud sync | Apple CloudKit | Whenever your saved places change |
| Yelp enrichment | api.yelp.com over HTTPS | Only if you've added a Yelp API key, and only when you tap "Enrich from Yelp" on a specific place |
| Open in Maps | Apple Maps or maps.google.com | When you tap the Maps menu on a place's detail screen |

## Permissions the app may request

| Permission | Why |
|---|---|
| **Location (when in use)** | To center the map on your current location and to add places at where you're standing. The location is never stored or sent off the device. |
| **Camera** | Only if you choose to attach a photo of a place. |
| **Photos** | Only if you choose to attach a photo from your library. |
| **iCloud (CloudKit)** | To sync your places across your Apple devices using your iCloud account. |

If you deny any of these permissions, the related feature is disabled but the rest of the app continues to work.

## Children's privacy

The app does not knowingly collect any data from anyone, including children under 13.

## Changes to this policy

If we change anything material we'll update this page and update the "Last updated" date at the top.

## Contact

Questions or concerns: max.leclercq.privacy@<your-email-domain>.com
