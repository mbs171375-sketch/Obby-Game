# Architecture and limits

The complete requirements supplied were sections 14–16, plus the request for a vibrant brainrot theme, a curving course with climbs and descents, and the later waiver of Claude review and Studio playtesting. There are no missing sections 1–13 to obtain.

## Project layout

| Location | Purpose |
|---|---|
| `tools/build_place.py` | Deterministic static map and place builder; standard-library Python |
| `src/shared/Config.luau` | Game tuning, cosmetic catalogue, optional creator-owned product IDs and audio |
| `src/shared/Rules.luau` | Engine-independent typed progression, promotions and profile transactions |
| `src/server/Game.server.luau` | Touch events, animated obstacles, progression, rewards, persistence and purchases |
| `src/client/Game.client.luau` | HUD, shop, settings, promotional art, responsive layout and local audio |
| `tests/rules.spec.luau` | Pure rules including receipt replays and interrupted credit use |
| `tests/server.spec.luau` | Production server code running on simulated services and a controllable clock |
| `tests/client.spec.luau` | Production client code running on those services, with UI event simulations |
| `tests/harness.luau` | Isolated deterministic service doubles and scheduler |
| `tests/offline.spec.luau` | Shipped zero-ID configuration with unavailable DataStore |
| `tests/place.spec.luau` | Real Roblox XML/binary deserialization using Lune/rbx-dom |
| `tests/test_map.py` | Full course topology, default jump reachability and deterministic builds |

The delivered places are standalone. There is no Rojo, runtime HTTP request, third-party plugin, external image, borrowed character model, or dynamically downloaded script. All models and UI art are built from original geometric shapes. Preview rendering and test tools are development-only.

## Course design

The route uses continuous sine curves in X, increasing Z, and an independent two-frequency height curve. Z increases monotonically, keeping far-apart stages from overlapping. Every world contains ten named obstacle beats. Neon islands mark progress and safe positions, but never change the player's respawn point. There is exactly one SpawnLocation in the lobby.

The route checker constructs a graph of platform rectangles and computes edge-to-edge gaps. It conservatively uses WalkSpeed 16, JumpPower 50 and gravity 196.2, with a 0.6-stud launch/landing margin. It excludes moving clouds and fading tiles, so every stage must also have a static free route. This checks geometric feasibility, not input feel, humanoid collision, latency, camera visibility or Roblox's full physics engine.

The fading route warns in amber before disappearing. Its side stones stay solid. The moving-cloud route also has permanent side stones. Lava and lasers are visibly pink; scenery does not have hidden collision. Springs and three-second speed boosts are free. Moving clouds carry riders by applying the platform's CFrame delta. Rotating anchored hazards additionally scan player-root overlap, since scripted CFrame changes alone cannot reliably produce touch events.

## Trust and data

Clients send only bounded action names and item identifiers. They cannot submit prices, balances, rewards, target stages or an ownership flag. The server validates stage order and proximity, rate-limits actions, and validates products against the configured catalogue. This is not a comprehensive movement anti-cheat: a determined client-side teleport exploit needs additional production movement validation.

Profiles use one DataStore key per player. Coins/wins save as deltas and best progress merges monotonically, preserving newer receipt updates. Local storage operations are serialized. Save outages keep unsaved deltas for retry; unpublished/initially unavailable storage uses an explicitly labelled session-only mode and disables purchases. A server crash before autosave can lose unflushed free rewards. There is no claim of cross-region transaction availability during an outage.

Developer Product receipts add one durable skip credit and store the purchase ID in the same atomic `UpdateAsync`. Duplicate IDs never add another credit. Unknown products and failed storage operations return `NotProcessedYet`. Purchase completion signals alone never grant Developer Products. Game Pass completion re-queries server-side ownership before granting benefits.

Using a credit creates a durable reservation. A death or disconnect during use refunds it; an interrupted reservation is recovered on next join. If final settlement fails after delivery, recovery may favour the player by returning that credit, rather than destroying a paid entitlement. The receipt ledger fails closed at 4,000 distinct receipts per player; shard/archive receipt records before operating at that scale. It never silently deletes deduplication records.

Client-side product queries obtain the user's regional price; a failed query hides the Buy offer rather than inventing a price. Prices and purchase eligibility still require live Roblox testing. All IDs default to zero.

## Promotions and presentation

The state machine checks a 50-second cadence and queues at most one offer. A card requires a living grounded character, a labelled Safe pad, low velocity and two continuous stationary seconds. Movement immediately hides it and retains the queued offer. Menus defer offers. Reminders can be disabled in Settings; the preference is saved when storage works. Coil and skip offers alternate, with speed/gravity alternating within coil offers. Already-owned or unavailable products are not advertised. There are no random paid rewards, urgency countdowns, fabricated discounts or automatic checkouts. Official Roblox prompts are opened only by explicit Buy actions. Platform purchase permissions remain enforced by Roblox.

The music default is an original 132 BPM tung-style percussion sequence using bundled footstep/jump samples and a pitched ping bass accent. Actual bundled audio availability and its sound quality need engine testing. Owned uploaded audio IDs can replace it in Config. Cosmetics provide body colour accents, a companion and trail; they do not replace the player's avatar body or clothing. Reduced motion removes UI tweening and confetti and restores the 27 dancing brainrot models to their static poses; moving gameplay obstacles remain active.

The scene contains 3,979 BaseParts, including the spawn. Decorative objects do not cast shadows. Streaming is disabled for predictable first-launch behaviour. Low-end mobile FPS, camera comfort and touch ergonomics remain unverified; this offline suite cannot establish them.
