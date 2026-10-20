# Update 2 — Tung's Mouth

Requested changes implemented:

- The wide level banner is replaced by a **216 × 76 px top-left card**, shrinking to **180 × 76 px** on phones. The full-width hint strip and central notification bar are removed. Small notifications now sit below the corner card. The right-hand shop/settings/restart rail is retained.
- **27 animated brainrot figures** now populate the lobby and course: Tung Tung Tung Sahur, Ballerina Cappuccina, Tralalero Tralala and Bombardiro Crocodilo. These are custom geometric renditions, with log grain, bats, coffee-cup handles/tutus, shark sneakers and crocodile-plane wings. They bounce and turn to the rhythm. Reduced Motion restores their stationary poses.
- **Ten extra rotating sahur bat hazards** sweep the left branch of the branching stages. The right lane remains free. Existing moving clouds, fading tiles, springs, boosts and spinning lasers remain.
- The old chiptune is replaced with an **original 132 BPM tung-style percussion loop**, using three pitched wood-like footstep voices, a clap, hat and bass accent. This is not a recording of a viral song or the character's voice. The existing Music toggle mutes every voice. An owned Roblox audio ID in `Config.MusicTracks` can supply a specific song instead.
- The final island has a **giant open-mouthed Tung**. Walk along the pink tongue to the win trigger inside his mouth. Merely reaching the island no longer awards victory. The entrance has a 21-stud opening and more than 9 studs of headroom.

Offline validation includes the full default-jump course, character/model counts, mouth entrance and trigger placement, no full-width gameplay HUD, corner sizing, animated poses, Reduced Motion restoration, the muted percussion voices, and the production server's arrival-versus-mouth victory behaviour. See `test-output.txt` for the latest run. Actual new music playback, live physics and rendering remain unverified in Roblox Studio.

Download the rebuilt `dist/BrainrotOrbit.rbxl` from the `brainrot-orbit-download` branch. Opening an old copy will still show the previous game.
