# Verification report

**Result: offline checks pass; this game is not FULLY VERIFIED.**

The supplied specification is sections 14–16 plus the vibrant brainrot/up-down-curving-course request. The requester waived Claude review and Roblox Studio playtesting. No Studio session, live Roblox purchase, real device test, external reviewer or Roblox screenshot is claimed. The preview image is explicitly an offline geometry illustration. No claim is made that this work took three hours.

## Checks actually executed

Run `python3 tools/verify.py --tools /workspace/obby-tools` in this cloud environment, or follow README for a local tool installation. Current command output is captured in `docs/test-output.txt`.

| Check | Result | Evidence and scope |
|---|---|---|
| Map topology and generation | PASS | 11 Python tests, including all 100 stage routes, all 10 worlds, climbs, descents, curvature, one spawn, visible hazards and deterministic rebuilds |
| Luau compilation | PASS | All four production source files compiled using Luau 0.743 |
| Shared-module strict type checks | PASS | `luau-analyze` passes Rules and Config; engine scripts were compiled/simulated, not type-checked against Studio's engine definitions |
| Pure progression, promotion and transaction rules | PASS | 68 assertions using the actual Rules module, including malformed data, timer boundaries, receipt replay, refunds and insufficient currency |
| Production server event wiring | PASS | 65 assertions executing the server script against deterministic service doubles, including a complete 100-stage run |
| Production client event wiring | PASS | 38 assertions executing the client script against service doubles; menus, regional-price display, settings, promotion deferral/hiding and compact layout |
| Disabled-product and unpublished-place mode | PASS | 16 assertions using an explicit zero-ID fixture and GetDataStore unavailable; full free run, earned cosmetics, restart and disabled checkout |
| Supplied Robux product configuration | PASS | 16 assertions exercise the creator-supplied pass/product IDs, lobby safe surfaces, checkout routes, ownership grants and ten-credit receipt replay using service doubles; no live payments |
| Roblox XML and binary serialization | PASS | 6,708 assertions using Lune 0.11.0/rbx-dom; 6,292 BaseParts, 100 stage models, four embedded scripts, one spawn and successful binary round trip |
| Tool installation repeatability | PASS | Pinned upstream Luau/Lune release archives downloaded with TLS and verified against fixed SHA-256 checksums before extraction |

Service doubles simulate DataStore, MarketplaceService, player events, touch signals, scheduling and UI objects. They cannot establish that Roblox services, physics, touch input, audio or rendered pixels behave identically. Analytical geometry is not a gameplay playtest. No failed offline check remains in the final captured run.

## Feature checklist

PASS entries below state the specific offline evidence; they do not imply unperformed engine testing. UNVERIFIED means implemented behaviour lacks direct engine/device evidence. BLOCKED identifies an external prerequisite. WAIVED identifies the two tests the requester removed from mandatory completion.

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| Complete 100-stage map exists | PASS | 100 models deserialized, numbered 1–100; simulated server run crossed every stage and reached marker 101 |
| Ten vibrant themed maps/areas | PASS | Ten distinct palettes, named world banners, original mascots, scenery and decorative structures present; taste/visual quality in Roblox unverified |
| Original brainrot-style theme | PASS | Ten themed worlds plus custom Tung, coffee ballerina, sneaker shark and crocodile-plane figures generated from geometric parts |
| Colourful lobby | PASS | Lobby island, coloured canopy kiosks, tree decorations, mascot, signs and original spawn are in the deserialized place; actual rendering unverified |
| Course goes up and down | PASS | Height curve includes more than 20 rising and 20 falling segments; geometry test verifies vertical range |
| Course curves instead of one straight line | PASS | X span over 350 studs and changing approach angles; continuous nonlinear route |
| All obstacles exist | PASS | Fourteen obstacle categories occur across ten differently shuffled worlds; generated manifest contains every stage's platforms |
| Free route through every stage | PASS | Conservative default-jump graph reaches each exit without paid coils, moving clouds or fading tiles; humanoid physics still unverified |
| Finish/victory area exists | PASS | Victory island, giant Tung mouth, tongue walkway, internal finish pad and server win reward are present |
| Complete course is enjoyable and polished in actual play | UNVERIFIED | Requires player feedback and engine observation; automated counts cannot establish enjoyment |
| No permanent respawn checkpoints | PASS | Exactly one SpawnLocation; no checkpoint scripts in the new place; death resets simulated run state |
| Spawn returns to original start | PASS | Server spawn routine and initial lobby-facing placement simulated; actual automatic Roblox respawn unverified |
| Progress is tracked independently of respawn | PASS | Simulated sequential stage progress, out-of-order rejection, repeat-touch rejection and death reset |
| Springs | UNVERIFIED | Server simulation verifies upward velocity 53; physical spring interaction not engine-tested |
| Free speed boosts | UNVERIFIED | Server simulation verifies speed 22 and baseline restoration after three seconds; actual movement not engine-tested |
| Conveyors/side accelerators | UNVERIFIED | Correct sideways velocity initialized in simulation; physical friction/network response not engine-tested |
| Moving platforms | UNVERIFIED | Heartbeat simulation moves the cloud and carries a standing root; actual networked rider comfort unverified |
| Fading tiles | UNVERIFIED | Timed solidity/warning cycle exercised; permanent free side route verified; real collision timing unverified |
| Lava hazards | UNVERIFIED | Touch simulation reduces health to zero; actual contact requires engine observation |
| Rotating hazards | UNVERIFIED | Simulated rotation changes; moving-hazard overlap scan is implemented; real contact and jump timing unverified |
| Character skins | UNVERIFIED | Coin purchase, original palette restoration, companion creation and free re-equip pass server simulation; rendered avatar appearance unverified |
| Requested Brainrot Rap recording | UNVERIFIED | User supplied audio ID 134764779929866, configured and SoundId verified in client simulation; actual Roblox playback/permissions unverified |
| Fictional speed leaderboard | PASS | Lobby NPC rivals board has fast invented times explicitly labelled FICTIONAL TIMES / NOT PLAYER RECORDS; not mixed with actual player stats |
| Music | UNVERIFIED | Original percussion sequencer and optional owned-track playlist implemented; simulated OFF stops notes; actual bundled sound playback unverified |
| Sound-effect controls | PASS | Simulated muted notifications do not call Sound.Play; actual sound output unverified |
| Reduced UI motion | PASS | Setting activation tested; transitions/confetti consult the option; rendered result unverified |
| HUD/progress/timer | UNVERIFIED | Server state reaches correct initial HUD; progress/coins/wins are simulated; visual clipping and timer appearance unverified |
| Shop interface | UNVERIFIED | Shop opens, rows and Buy callbacks work in simulation; real rendered interface requires external observation |
| Interactive lobby shops | UNVERIFIED | Two ProximityPrompts and client callbacks exist; actual distance/keyboard/touch prompts unverified |
| Restart confirmation | UNVERIFIED | Confirmation and server reset implemented; server reset tested; full rendered interaction unverified |
| Leaderboard | UNVERIFIED | Default Roblox player-list leaderstats created and updated; real CoreGui display not observed |
| Persistent coins/wins/best/skins/preferences | UNVERIFIED | Transform and service-double tests pass; real DataStore access and reconnect persistence untested |
| Save outage fallback | PASS | Storage failure yields explicitly session-only state; simulated paid prompts disabled; production outages untested |
| Speed and gravity coils | UNVERIFIED | Server verifies ownership and applies speed 23 / jump power 62, with baseline restoration; physical benefits/visuals unverified |
| Stage skip credits | UNVERIFIED | Product 3720254856 configured for ten credits; atomic grant/replay/spend tests pass; live receipt delivery unverified |
| Game Pass purchases | UNVERIFIED | Speed Coil 2038121195 and Jump Boot 2041634630 configured as creator-confirmed Game Passes; actual ownership and live checkout unverified |
| Developer Product receipt processing | PASS | Duplicate receipts do not duplicate credits, unknown/offline/outage receipts retry, credit is persisted before acknowledgement in service doubles; real MarketplaceService delivery untested |
| RemoteEvent validation | PASS | Bounds/type checks, ownership gates, sequential stage checks and rate flood tested; comprehensive movement anti-cheat is outside this implementation |
| Multiplayer state separation | PASS | Three simulated users maintain independent state; actual multiplayer latency/physics unverified |
| 50-second recurring promotion timer | PASS | Exact timer boundaries and no catch-up spam checked in Rules; production client queues an offer after 50 simulated seconds |
| Alternate coil and skip offers | PASS | Speed → skip → gravity → skip tested in Rules; client alternation exercised |
| Correct regional Robux price | UNVERIFIED | Client regional-price query tested against service doubles; live prices for supplied IDs unverified |
| Original graphics and card animation | UNVERIFIED | Geometric art and tweens implemented; no external image dependencies; real rendering unverified |
| Clear X dismissal | PASS | Card dismissal tested; menu rail restored after dismissal |
| Never interrupt active jumps/danger | PASS | Ground, velocity, safe marker and dwell gates implemented; simulated danger defers and movement hides; actual frame/input behaviour unverified |
| Queue until safe | PASS | Rules queue in danger; actual client code displays after two stationary simulated safe seconds |
| Card small enough to retain controls | UNVERIFIED | Compact card width 238 verified for a 375-wide viewport; real occlusion and joystick ergonomics require device testing |
| Never automatically open checkout | PASS | Automatic card display produces no simulated native prompt; only Buy sends the purchase action |
| Deliberate Buy opens official prompt | PASS | Production client button and server handler invoke simulated official purchase route only for configured/available items |
| Reminder opt-out in Settings | PASS | Client ON/OFF responds, queue is cleared, preference saved in service double |
| No false urgency/discount pressure | PASS | No countdown, fake discount, scarcity or auto-checkout in code/card copy |
| Purchase permissions/younger-player policy | UNVERIFIED | Uses official optional purchase prompts and no random paid rewards; no claim of platform policy certification or live account-permission testing |
| Free players can finish | PASS | All geometry routes use default free movement; zero configured products do not gate map progress |
| Desktop input | UNVERIFIED | Standard Roblox controls and Activated handlers implemented; no actual desktop engine session |
| Mobile compatibility | UNVERIFIED | Compact layout branch and shared Activated wiring tested; no device emulation, touch rendering or FPS measurements |
| Controller input | UNVERIFIED | Shop/close key bindings and selectable controls implemented; navigation needs real controller testing |
| No important Output runtime errors | UNVERIFIED | Source compilation and service-double scripts report no test errors; Roblox Output window unavailable |
| No known game-breaking bugs | UNVERIFIED | No failures remain in accessible offline suites; engine/runtime defects cannot be ruled out |
| Claude independent review | WAIVED | Explicitly removed by requester; not performed |
| Roblox Studio playtest | WAIVED | Explicitly removed by requester; not performed |
| At least three hours of work | UNVERIFIED | No three-hour duration claim is made; deliverables and executed checks are the evidence offered |

## Remaining external actions

The standalone free place and all source are delivered. The creator supplied all three product IDs and confirmed their types; they are configured. Publish this build over the same experience that owns those products, enable pass sales, and use Roblox's supported testing flow. No credentials or real purchases were requested or invented. Real persistence needs an owned published experience. Engine physics, rendering, audio, performance and devices remain unverified even though Studio playtesting was waived.

Keep these distinctions when sharing the game: **implemented**, **offline tested**, **live configured**, **engine verified**, and **published** are different states. The project has not been published by this agent.
