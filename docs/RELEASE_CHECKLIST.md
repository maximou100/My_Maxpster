# Release Checklist — App Store Submission

A linear walkthrough of every step from "code is done" to "live on the App Store". Tick each box as you go.

---

## Phase 1 — Sanity checks on your Mac (15 min)

- [ ] **Run on a real iPhone** (Xcode → device picker → your iPhone → Run). Confirm: seed completes with progress bar, places appear on map, you can add/edit/delete a place.
- [ ] **Run on a real iPad.** Confirm the sidebar TabView shows, the map renders.
- [ ] **Verify CloudKit sync** by adding a place on the iPhone and watching it appear on the iPad after ~30s. Both devices must use the same Apple ID with iCloud Drive on.
- [ ] **Test export.** Settings → Data → Export as CSV → share → email it to yourself. Open the CSV in Numbers or any spreadsheet app.
- [ ] **Bump version + build number.** In Xcode, target → General → Identity:
  - Version: `1.0` (for first release)
  - Build: `1` (increment on every TestFlight upload)

---

## Phase 2 — App Store assets (30 min)

- [ ] **Marketing icon (1024×1024 PNG, no alpha, no rounded corners).** Your current `Maxpster1.1.png` should work. Verify in Xcode: target → General → App Icons and Launch Images, no warnings.
- [ ] **Capture screenshots** in the simulator. See `STORE_LISTING.md` for the required sizes and suggested shots. Drag-drop into App Store Connect later.
- [ ] **Privacy policy + Support pages** — see Phase 3 below to host them.

---

## Phase 3 — Host privacy & support pages on GitHub Pages (10 min)

The privacy policy URL is **required** by Apple. Easiest option: GitHub Pages on this repo, free.

1. Go to **https://github.com/maximou100/My_Maxpster/settings/pages**
2. Source: **Deploy from a branch**.
3. Branch: `main`, folder: `/docs`. Save.
4. Wait 1–2 min, then visit `https://maximou100.github.io/My_Maxpster/PRIVACY` — should render the privacy policy.
5. Same for `https://maximou100.github.io/My_Maxpster/SUPPORT`.

Once those URLs are live, you'll paste them into App Store Connect.

---

## Phase 4 — Apple Developer setup (15 min, one-time)

- [ ] **App ID exists.** Visit https://developer.apple.com/account/resources/identifiers/list → check for `Max-Leclercq.My-Maxpster`. If not present, click `+` → App IDs → App → Bundle ID = `Max-Leclercq.My-Maxpster` → Enable **iCloud** (Include CloudKit support) + **Push Notifications**.
- [ ] **CloudKit container** exists. https://developer.apple.com/account/resources/iclouds → verify `iCloud.com.maxleclercq.My-Maxpster` is listed. If not, create it and link it to the App ID.
- [ ] **CloudKit schema deployed to Production.** Go to https://icloud.developer.apple.com/dashboard/database → pick `iCloud.com.maxleclercq.My-Maxpster` → **Deploy Schema Changes** (top-right). Confirm the diff, deploy. Without this, App Store users get an empty CloudKit DB.

---

## Phase 5 — Create the app in App Store Connect (10 min)

- [ ] Go to https://appstoreconnect.apple.com → **My Apps** → **+** → **New App**.
- [ ] Fill the form:
  - Platforms: **iOS**
  - Name: **My Maxpster**
  - Primary Language: **English (U.S.)**
  - Bundle ID: pick `Max-Leclercq.My-Maxpster` from the dropdown.
  - SKU: anything unique, e.g. `my-maxpster-2026`.
  - User Access: Full Access.

---

## Phase 6 — Fill the App Store metadata (30 min)

Open your new app in App Store Connect.

- [ ] **App Information** tab:
  - Subtitle, Category (primary + secondary) — from `STORE_LISTING.md`
  - Privacy Policy URL — `https://maximou100.github.io/My_Maxpster/PRIVACY`
- [ ] **Pricing and Availability**:
  - Price: Free
  - Availability: All countries
- [ ] **App Privacy** (the "nutrition labels"):
  - Click **Get Started** → tick **Yes** for Data Collection.
  - Then declare **Location → Precise Location**, **User Content → Photos or Videos**, **User Content → Other User Content**, all NOT linked to user identity, NOT used for tracking. See `STORE_LISTING.md` table.
- [ ] **Version 1.0** screen (the iOS section):
  - Description, Keywords, Promotional Text, Support URL, Marketing URL — copy from `STORE_LISTING.md`.
  - Drag in your 6.7" iPhone + 13" iPad screenshots.
  - **What's New** for first release: "Initial release."
- [ ] **App Review Information**:
  - Contact info (name, phone, email).
  - Demo account: leave blank (no login).
  - Notes: paste the block from `STORE_LISTING.md` → Review notes section.

---

## Phase 7 — Upload the build from Xcode (15 min)

- [ ] In Xcode, set the run destination to **Any iOS Device (arm64)**.
- [ ] **Product → Archive**. Wait for the archive to finish (5–10 min depending on machine).
- [ ] Xcode Organizer opens. Pick the new archive → **Distribute App** → **App Store Connect** → **Upload**.
- [ ] Xcode validates and uploads. If it complains:
  - Missing app icon size → add it to `AppIcon.appiconset`.
  - Invalid entitlements → confirm CloudKit + Background Modes are still checked in Signing & Capabilities.
- [ ] Once upload succeeds, Apple processes the build for ~15–60 min. You'll get an email when it's ready.

---

## Phase 8 — TestFlight (optional but recommended) (1 day)

- [ ] In App Store Connect → your app → **TestFlight** → wait for the processed build.
- [ ] Add yourself as an **Internal Tester** under "App Store Connect Users".
- [ ] Install **TestFlight** from the App Store on your iPhone. Open it → install your build. Test once on the real-world build (not a dev build).
- [ ] If you find bugs, fix them, bump the build number, archive + upload again. Each upload appears in TestFlight within an hour.

---

## Phase 9 — Submit for review (5 min)

- [ ] In App Store Connect → your app → **App Store** tab → version 1.0:
  - Under **Build**, pick the build you uploaded.
  - Make sure all required fields are filled (App Store Connect shows red dots next to anything missing).
- [ ] Click **Add for Review** → then **Submit for Review**.

Apple's review typically takes **24–48 hours**. You'll get an email with the decision.

---

## Phase 10 — After approval

- [ ] If you chose **Manual release**, click **Release This Version** in App Store Connect when you're ready.
- [ ] Otherwise it goes live automatically.

---

## Most common rejection reasons (and how to avoid)

1. **Missing privacy policy URL.** Done in Phase 3.
2. **Inaccurate App Privacy declarations.** Match what the app actually does — see `STORE_LISTING.md`.
3. **App crashes during review.** They test on whatever device they have. Ensure the seed flow doesn't hang on a clean install.
4. **Insufficient demo instructions.** The Review Notes in `STORE_LISTING.md` cover what they need.
5. **Beta-quality UI / placeholder text.** Make sure no "TODO" or "Lorem ipsum" is visible.

---

## Updating the app later

For every subsequent version:

1. Bump version + build number in Xcode.
2. Update `What's New` in App Store Connect.
3. Re-archive, upload, submit. The whole flow takes ~30 min.
