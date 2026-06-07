---
layout: default
title: Support
---

# My Maxpster — Support

## Common questions

**The map is showing a blank screen on first launch.**
The first launch downloads map tiles from Apple Maps and syncs your library to iCloud. Give it 5–10 seconds. If after that the screen is still blank, force-quit the app and reopen — the second launch is always faster because tiles are cached.

**My places aren't showing on my other device.**
Make sure both devices are signed into the same Apple ID and have iCloud Drive switched on (Settings → [your name] → iCloud). iCloud sync uses Apple's CloudKit; new places usually appear on a second device within 30 seconds.

**I lost my places — can I get them back?**
Your places are stored in your iCloud account, not on the developer's servers. If you've signed into the same Apple ID with iCloud on, your places should re-appear when you reinstall the app. If you've deleted them yourself, they can't be recovered (the app has no Trash/Undo at the moment).

**How do I export everything?**
Settings → Data → Export as CSV (or GeoJSON). The CSV is Mapstr-compatible; the GeoJSON works with any map app that supports the standard.

**How do I import from Mapstr or Google Maps?**
- **Mapstr:** Settings → Data → "How to export from Mapstr" walks you through it.
- **Google Maps:** Settings → Synchronization → "How to export from Google Maps" walks you through the Google Takeout flow.

**What's the Yelp integration?**
Optional. When you provide a free Yelp Fusion API key in Settings → External services → Yelp, each place detail screen gains an "Enrich from Yelp" button that fetches the rating, price tier, phone, and website from Yelp.

## Contact

Email: max.leclercq.support@<your-email-domain>.com

Please include your device model and iOS version when reporting an issue.
