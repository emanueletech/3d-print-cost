# What does your print REALLY cost? I built a free app to answer that

*[FOTO 1 — mw-cover.png · copertina]*

Every maker gets the same question sooner or later: **"how much does it cost to print that?"**

For years my honest answer was "…the filament? Maybe three euros?" — and I design and print a lot. Filament is the only cost we all count, but it's not the only one: there's electricity, machine wear, the heat-up of every plate, and the prints that fail and get thrown in the box of shame. None of that shows up in the slicer.

So I built **3D Print Cost**: a free desktop app (Windows + macOS) that reads your **already-sliced .3mf** files from Bambu Studio or OrcaSlicer and turns them into real numbers. No re-slicing, no accounts, no cloud — you drop the file, it reads what your printer is actually going to do.

## A real example: my Jack Skellington BRICK

Let me show you with my most popular model, the [Jack Skellington BRICK – Special Edition](https://makerworld.com/en/models/665209-jack-skellington-brick-special-edition) (a 23 cm build in three matte colors — Ivory White, Charcoal and Nardo Gray).

I dropped the sliced .3mf into the app and this is what came out:

*[FOTO 2 — mw-overview.png · panoramica con Jack caricato]*

At a glance: **16 hours** of printing across 8 plates, just over **400 g** of filament split by color, about **3.1 kWh** of electricity, and — the number I never had before — the **real cost of the print**.

## The number nobody calculates

The "Real print cost" panel is why this app exists. It adds up five things:

*[FOTO 3 — mw-realcost.png · dettaglio della scomposizione]*

- **Material used** — grams × the €/kg of the actual material matched to each color;
- **Energy** — print hours × your printer's average wattage × your electricity price;
- **Machine wear** — printer price ÷ useful life, per hour of printing;
- **Setup / starts** — every plate costs a heat-up and a calibration;
- **Failures** — a configurable percentage to cover the prints that don't make it.

For my Jack that's **$16.06** — not the "three euros of filament" I would have guessed. If you sell your prints, this is the number your price should start from. If you print for fun, it's still good to know what your hobby actually burns.

The app also answers the other everyday question: **which spools do I need to buy?** It groups material by color, rounds up to whole spools, and applies Bambu's volume discounts automatically (−35% at 4, −45% at 6, −50% at 10 spools).

*[FOTO 4 — mw-colors.png · colori e bobine]*

## Your materials, your printers

Under the hood there's an editable database of materials (Bambu palette pre-loaded, with €/kg, density and even a "sale price" field for when you catch a promo) and of printers — wattage, hourly wear and startup cost per plate. Defaults are ready for the whole Bambu line-up; everything is tweakable.

*[FOTO 5 — mw-materials.png · database materiali]*

A few more things it does:

- **Plate merge advice** — finds light same-color plates you could combine to save heat-ups;
- **3D orient** — load an STL/STEP/OBJ and compare orientations by support area before slicing;
- **Batch mode** — drop ten projects at once and see combined totals;
- **4 languages** (EN/IT/ES/FR), currency conversion, and it works **fully offline**: your files never leave your computer.

## How to get it

Free download from GitHub — pick your system on the Releases page:

**➜ github.com/emanueletech/3d-print-cost/releases/latest**

- **Windows 10/11**: installer or single portable .exe
- **macOS 26+ (Apple Silicon)**: .dmg

One honest note: the app has no paid code-signing certificate, so Windows and macOS show a warning on first launch. The README explains the one-time fix for both (it's the usual "More info → Run anyway" / right-click → Open).

## Free, with one small ask

*[FOTO 6 — mw-unlock.png · sblocco in due passi]*

The app is completely free and the source code is public. In return I only ask for a follow: on first launch you open one of my profiles (Instagram, MakerWorld or YouTube), then the Telegram bot unlocks the app with one tap. That's the whole "price". If it saves you from underpricing even one commission, it already paid for itself.

## Your turn — #RealPrintCost

Here's a challenge: take your latest print, drop the .3mf into the app, and comment below with **what you thought it cost vs. what it really cost**. I'll start: Jack Skellington BRICK — I would have said $5. Real number: **$16.06**.

I bet nobody gets within 30%. Prove me wrong 👇
