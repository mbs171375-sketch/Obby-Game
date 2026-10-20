# Connected Robux products

The creator confirmed the item types and supplied these IDs:

| Item | Roblox type | ID | Benefit |
|---|---|---|---|
| Speed Coil | Game Pass | 2038121195 | WalkSpeed 32 instead of 16 |
| Jump Boot | Game Pass | 2041634630 | JumpPower 80 instead of 50 |
| 10 Stage Skips | Developer Product | 3720254856 | Moves forward up to ten stages in one use |

The shop is Robux-only; coin rewards, the coin HUD/leaderboard and coin cosmetic purchases have been removed. Historical profile fields remain readable so existing saves are preserved.

Both Game Passes automatically enable when ownership is confirmed on join and stay enabled after respawn. They work together. **OWNED • ON/OFF** independently toggles each actual movement effect; it never charges an owner again. Unowned passes show the live Robux Buy price. Jump Boot uses the internal Gravity slot.

The repeatable Developer Product saves ten stages atomically per unique receipt. When bought from a safe island during a run, it immediately advances up to ten stages. Otherwise, the shop's **SKIP +10** button delivers them once safely stationary in the course. Near the finish, only the remaining stages are consumed; the balance stays saved. A duplicate receipt cannot repeat a grant or teleport. Failed/interrupted delivery refunds the full reserved quantity, including legacy single-stage reservations. Death still resets run progress.

Prices are fetched from Roblox, including a client query for regional pricing. No Robux amount is invented or hard-coded. Items must be on sale and return valid price information. Purchasing is disabled while DataStore is unavailable. Promotions queue on a 50-second cadence and display only while the living character is grounded and still for two seconds on a safe surface. The lobby lawn/spawn and numbered islands are safe surfaces. Settings can disable reminders. The card itself never launches checkout; Buy must be selected explicitly.

## Publish this version

1. Download the updated rbxl and open it in Roblox Studio.
2. Choose File → Publish to Roblox As… and select the **same existing experience** that owns these products. Do not accidentally create a new experience for each download.
3. Keep both Game Passes on sale in Creator Dashboard, with the prices you want. Keep the Developer Product configured for this experience.
4. Test in the published Roblox experience. For a Studio persistence test, enable Studio Access to API Services in the experience's security settings. An unpublished file may be session-only and intentionally disables paid checkout.
5. Confirm shop prices, ownership/equip behaviour and the safe lobby reminders. Use supported Roblox test procedures for purchases; do not make real purchases simply to test.

The offline suite exercises all three exact configured IDs against service doubles and tests ten-credit receipt replay/consumption. Real marketplace validation, price availability, permissions, checkout and DataStore delivery are not claimed as verified here. The creator's confirmation establishes the intended configuration, not a live Roblox transaction test.
