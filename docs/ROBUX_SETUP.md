# Connected Robux products

The creator confirmed the item types and supplied these IDs:

| Item | Roblox type | ID | Benefit |
|---|---|---|---|
| Speed Coil | Game Pass | 2038121195 | Equip for increased running speed |
| Jump Boot | Game Pass | 2041634630 | Equip for increased jump power |
| 10 Stage Skips | Developer Product | 3720254856 | Adds ten durable skip credits; use one per stage |

Jump Boot uses the internal Gravity slot; its shop and promotional label is Jump Boot. Game Passes are permanent ownership purchases with equip/unequip controls. The Developer Product can be purchased repeatedly. Ten credits are granted atomically per unique receipt; replaying the same receipt does not grant more. Spending one credit advances only the current obstacle; unused credits remain saved. A failed/interrupted use does not silently destroy the entitlement. Death still resets run progress.

Prices are fetched from Roblox, including a client query for regional pricing. No Robux amount is invented or hard-coded. Items must be on sale and return valid price information. Purchasing is disabled while DataStore is unavailable. Promotions queue on a 50-second cadence and display only while the living character is grounded and still for two seconds on a safe surface. The lobby lawn/spawn and numbered islands are safe surfaces. Settings can disable reminders. The card itself never launches checkout; Buy must be selected explicitly.

## Publish this version

1. Download the updated rbxl and open it in Roblox Studio.
2. Choose File → Publish to Roblox As… and select the **same existing experience** that owns these products. Do not accidentally create a new experience for each download.
3. Keep both Game Passes on sale in Creator Dashboard, with the prices you want. Keep the Developer Product configured for this experience.
4. Test in the published Roblox experience. For a Studio persistence test, enable Studio Access to API Services in the experience's security settings. An unpublished file may be session-only and intentionally disables paid checkout.
5. Confirm shop prices, ownership/equip behaviour and the safe lobby reminders. Use supported Roblox test procedures for purchases; do not make real purchases simply to test.

The offline suite exercises all three exact configured IDs against service doubles and tests ten-credit receipt replay/consumption. Real marketplace validation, price availability, permissions, checkout and DataStore delivery are not claimed as verified here. The creator's confirmation establishes the intended configuration, not a live Roblox transaction test.
