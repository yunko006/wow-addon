# PIGlow

PI Timer Calculator for WoW Midnight (12.0). Tells you when to cast Power Infusion based on your target's cooldown timings.

## How it works

1. `/pig` to open the config menu
2. Choose a player in your raid/group
3. The addon auto-detects their spec and calculates optimal PI timings
4. At pull, alerts appear on screen when it's time to PI

Two modes:
- **Auto**: calculates timings from the target's main CD (e.g. Pillar of Frost 60s → PI at 0:00, 2:00, 4:00...)
- **Manual**: enter custom timings for specific boss strategies

## Commands

- `/pig` — open config menu
- `/pig test` — test the alert
- `/pig clear` — reset config
- `/pig status` — show current config

## Install

Copy the `PIGlow` folder to `World of Warcraft/_retail_/Interface/AddOns/`.

## Zero dependencies

No external libraries. No combat API calls. Pure math timers.
