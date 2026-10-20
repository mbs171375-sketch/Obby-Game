# Update 3 — Switchback chaos

- The 100-stage course is now over 6,000 studs long, with ten distinct rising/falling switchback sections. Worlds change direction and climb into taller sky areas; the route is not a circular lap.
- Each world has a different, reproducibly shuffled order of ten obstacle types. Across the course there are 14 categories, rather than the same ten-stage loop repeated in every world.
- Ten sections contain disappearing stairs that travel vertically. Ten more use rising/falling elevator steps. Ten have touch-triggered crumbling stairs with an amber warning and automatic restoration.
- Ten dodge bridges each have two large swinging balls on visible cables. Their movement follows pendulum arcs, and server-side overlap checks detect contact. Stable side paths give free players an alternative, and invisible stairs cannot carry unsupported players.
- The lobby now has a fast-time rivals board. Its names and times are fictional and clearly marked **NPC RIVALS / FICTIONAL TIMES / NOT PLAYER RECORDS**. Existing actual player Stage/Wins/Coins leaderstats are separate.
- Tung's mouth remains the finish, and the compact corner HUD and right-hand shop rail are retained.

The requested song is identified by `https://www.youtube.com/watch?v=T_NKi5KHUdI`. The YouTube URL is a reference in Config, not a playable Roblox asset. The exact recording is **not included**. To use it, supply an uploaded Roblox audio asset ID that the experience has permission to use, then set `MusicTracks = { AUDIO_ASSET_ID }` in Config and rebuild. The original percussion loop remains the fallback. No YouTube audio was downloaded, reuploaded, or claimed as licensed.

Common obby ideas—switchbacks, vanishing stairs, timed platforms, moving lifts and pendulum dodging—inspired these original layouts. No other game's map or code was copied. Automated checks validate geometry and simulated game logic; live physics, audio playback and mobile performance still need Roblox observation.
