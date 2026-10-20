# BRAINROT ORBIT

A colourful, standalone Roblox obby: **100 stages, 10 original meme worlds, one run**. The floating course climbs, drops and bends through noodle planets, toast goblin skylines, frog frequencies, galaxy geese and disco dumplings.

**Open [dist/BrainrotOrbit.rbxl](dist/BrainrotOrbit.rbxl) in Roblox Studio using File → Open from File.** The editable XML version is [dist/BrainrotOrbit.rbxlx](dist/BrainrotOrbit.rbxlx). Both include the map and all scripts; no plugins or package installation are needed to open them. The original `obby_Game.rbxl` is preserved separately.

![Offline geometry preview, not a Roblox screenshot](docs/course-preview.png)

**Movement correction:** [Platform/stair snagging fixes](docs/FIX_STUCK_CHARACTER.md): non-colliding island collars, client-owned carry, and safe platform restoration. Latest music ID: `134764779929866`.

**Update 3:** [Switchback chaos](docs/UPDATE_3.md): 6,889-stud route, shuffled obstacles, disappearing moving stairs, lifts, crumbling steps, swinging balls, and a labelled NPC rivals board. Brainrot Rap is configured with the supplied audio asset `134764779929866`; actual playback and experience permissions remain unverified.

**Update 2:** [Tung’s Mouth update notes](docs/UPDATE_2.md): smaller corner HUD, dancing brainrot figures, rotating bats, original percussion, and a giant mouth finish.

The automated offline checks pass. **Roblox gameplay, physical devices, actual audio and live purchases have not been verified.** Claude review and Studio playtesting were waived by the requester; that waiver is not a passing test. See [verification results](docs/VERIFICATION.md) and [captured test output](docs/test-output.txt).

## What is included

- Ten worlds with ten stages each, original geometric mascots, floating scenery, neon edging, signs, a colourful lobby and a victory island.
- Fourteen obstacle categories: stepping stones, zigzags, narrow beams, lava, spinners, fading tiles, conveyors, springs, moving clouds, branching lanes, vanishing moving stairs, vertical lifts, pendulum balls and touch-triggered crumble stairs.
- A free default-jump route through every stage, including permanent side routes around timed tiles, lifts, moving clouds and swinging balls.
- Death resets the entire run to the original lobby. There are **no respawn checkpoints**. Coins, best progress, wins, cosmetics and unused skip credits are separate from run progress.
- Earn two coins per completed intermediate stage and 100 bonus coins at the finish. Five character palettes with matching trails and original companions use earned coins.
- Server-owned progression, default Roblox player-list leaderboard, run timer, restart confirmation and optional coil/skip shop.
- Speed and gravity coils; durable developer-product skip credits; replay-safe receipt processing; server checks on ownership, proximity, order and request frequency.
- Optional promotion cards checked every 50 seconds, alternating coil and skip offers. Cards queue until two safe stationary seconds, disappear on movement, dismiss with X, and never automatically open checkout.
- Saved settings for reminders, music, effects and reduced UI motion. Brainrot Rap uses the supplied Roblox audio ID. Clearing MusicTracks selects the original bundled-sound percussion loop.
- Compact phone layout, scrollable menus, `Activated` buttons for mouse/touch/controller, B or controller Y to open the shop, and controller B to close menus. Device rendering still needs external verification.

## First launch

1. Open **`dist/BrainrotOrbit.rbxl`**, rather than the original prototype.
2. Press **F5** to run. Walk from the lobby towards the first numbered island. Jump with Roblox's normal controls. Tap SHOP or use a lobby kiosk to browse.
3. Unpublished Studio sessions may lack DataStore access. The game falls back to session-only progress and disables paid purchases. It should not require an API key.
4. For persistent progress, publish to an experience you own. To test persistence *inside Studio*, enable **Studio Access to API Services** in that test experience's security settings.

## Optional Robux products

All product IDs deliberately default to **0**. The free course and coin cosmetics work without paid products; Robux items show **NOT ON SALE** and no purchase reminders are shown until configured.

In Studio, edit `ReplicatedStorage → OrbitShared → Config`, or edit `src/shared/Config.luau` and rebuild:

| Config entry | Creator-owned item needed |
|---|---|
| `Products.Speed.Id` | Speed Coil Game Pass ID |
| `Products.Gravity.Id` | Gravity Coil Game Pass ID |
| `Products.Skip.Id` | Skip Current Stage Developer Product ID |

Create the products for this experience in Creator Dashboard and set their prices there. **Do not enter Robux prices in the code.** Client-side product queries retrieve regional prices; the official Roblox checkout is authoritative. No IDs or purchase tests were invented. The server grants paid skip credits only after a durable DataStore update and keeps them until the player explicitly uses one while safe. Death resets progress even after a skip.

## Build and verify

Python 3.10+ builds the editable place with the standard library:

```sh
python3 tools/build_place.py
```

For the full offline suite on Linux x86_64, install the checksum-pinned Luau 0.743 and Lune 0.11.0 tools:

```sh
python3 tools/bootstrap_tools.py --destination .test-output/tools
python3 tools/verify.py --tools .test-output/tools
```

This builds the XML, checks all 100 routes, compiles all production Luau, type-checks the shared modules, runs real shared rules and production server/client scripts against service doubles, validates the place using Lune's Roblox reader, and writes the binary place after a successful round trip. It stops on any failure. The tool installer requires GitHub/release asset network access and verifies pinned SHA-256 checksums before extracting executables.

The geometry suite also runs independently without extra tools:

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

`python3 tools/render_preview.py` optionally regenerates the offline design preview with Matplotlib. It is a geometry illustration, not evidence of Roblox gameplay.

Edit sources under `src/` and the map generator under `tools/`. Rebuilding replaces generated files in `dist/`; do not edit those files and then rebuild without preserving your edits. Save Studio edits as a separate file if you want to keep them. See [architecture and limits](docs/ARCHITECTURE.md) and [external test instructions](docs/EXTERNAL_TESTS.md).
