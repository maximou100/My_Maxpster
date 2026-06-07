# App Store Listing — copy/paste reference

Paste these into App Store Connect during submission. Tweak to taste.

## Name (max 30 chars)

```
My Maxpster
```

## Subtitle (max 30 chars)

```
Your places, on a map.
```

## Primary category

Travel

## Secondary category

Lifestyle

## Description (max 4000 chars)

```
My Maxpster is a personal place-management app. Save the restaurants, bars, cafés, museums, beaches and other locations you've been to or want to visit — all on a single Apple Maps view, all on every Apple device you own.

Why you might like it
• Everything is local and private. No accounts, no analytics, no ads.
• Your library syncs across iPhone, iPad and Mac through your own iCloud — silently, with no setup beyond signing in.
• Imports the formats you already have: Mapstr backups (CSV + GeoJSON) and Google Maps "Saved" lists exported via Google Takeout.
• Exports the same way, anywhere. Share a CSV or GeoJSON via the standard iOS share sheet.

What's inside
• Map tab — Apple Maps with category-colored pins, long-press to add a place, online search via Apple Maps with one-tap "add to my places" preview.
• Places list — searchable and sortable with shared filters.
• Filters — category, visit status, minimum rating, tags, country, collection.
• Collections — browse places by category, tag, country, or by manual collections you create.
• Dashboard — totals, category breakdown, rating distribution, top tags, countries (Swift Charts).
• Open any place in Apple Maps or Google Maps.
• Optional Yelp enrichment — provide your own free Yelp Fusion API key and pull rating, price tier, phone, and Yelp page URL directly into a place.

Privacy
My Maxpster has no server. The developer cannot see your places. Your data lives only on your devices and in your own iCloud account. The app never displays ads and ships with zero third-party SDKs.
```

## Keywords (max 100 chars, comma-separated)

```
places,map,travel,wishlist,restaurants,cafe,bar,visited,mapstr,google takeout,bookmarks,icloud,trip
```

## Promotional text (max 170 chars, can update without resubmitting)

```
Save the places you love. Import your Mapstr & Google Maps libraries in seconds. Sync via iCloud across all your Apple devices. Private by default. No accounts.
```

## What's new in this version

```
Initial release.
```

## Support URL

(use the GitHub Pages URL after enabling — see RELEASE_CHECKLIST.md step 8)
```
https://maximou100.github.io/My_Maxpster/SUPPORT
```

## Marketing URL (optional)

```
https://maximou100.github.io/My_Maxpster/
```

## Privacy policy URL (required)

```
https://maximou100.github.io/My_Maxpster/PRIVACY
```

## App Privacy nutrition labels

Tick these when you fill out App Store Connect → App Privacy:

| Data category | Linked to user? | Tracking? | Purpose |
|---|---|---|---|
| **Location → Precise Location** | No | No | App Functionality |
| **User Content → Photos or Videos** | No | No | App Functionality |
| **User Content → Other User Content** (your saved places) | No | No | App Functionality |

Nothing else is collected.

## Age rating

4+ (no objectionable content, no in-app purchases, no UGC visible to other users)

## Pricing

Free

## Availability

All countries / regions

## Screenshots (you have to capture these in the simulator)

Required iPhone size: **6.7"** (iPhone 16 Pro Max simulator) — App Store now auto-derives smaller sizes from this.
Required iPad size: **13"** (iPad Pro M4 13" simulator).

Suggested set (3–5 each):
1. Map tab with pins and the search bar visible
2. A place's detail screen showing rating, tags, "Open in Maps" menu
3. Collections tab — Categories / Tags / Countries hub
4. Dashboard with charts
5. Settings → Import flow

To capture: Run on the simulator → Device → Screenshot. They land in `~/Desktop/`. Drag them into App Store Connect → Media → Screenshots.

## Review notes (Test Information section)

Paste the following so the Apple reviewer knows how to test:

```
Test instructions:

1. The app seeds itself on first launch with a small sample dataset of saved places (~250 entries from a personal export). No login required.

2. iCloud sync is enabled. The test device must be signed into iCloud for sync to work, but the app is fully usable without iCloud.

3. The Yelp integration is optional and gated behind the user pasting their own Yelp Fusion API key in Settings → External services → Yelp. Without a key, the "Enrich from Yelp" button on a place's detail screen is hidden.

4. No accounts, no in-app purchases.

5. To exercise the import flow: Settings → Data → Import (CSV / GeoJSON). The bundled mapstr files can also be re-imported via Settings → Data → Reset & Re-import bundled data.
```
