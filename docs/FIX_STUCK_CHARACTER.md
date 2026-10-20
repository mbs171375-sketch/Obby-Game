# Character snagging correction

The player reported getting stuck at platform edges and stairs. The exact live-engine incident was not reproduced in this Linux environment. Inspection found these collision and movement risks:

1. Each numbered island's decorative underside was larger than its playable pad and had collision enabled. All 100 decorative collars are now non-colliding and excluded from ground queries.
2. Non-colliding decoration could still intercept support raycasts. Generated decoration now has CanQuery false, and ground checks respect CanCollide.
3. The server previously called character PivotTo on every moving-platform Heartbeat. Repeated server corrections could fight client-owned movement. The server now animates only the platforms. The owning client adds the contacted platform's small translation to the current root position, preserving player walking input. Jumping, freefall, disappearing platforms, changed characters and changed supports release/reset carry state.
4. Fading and crumbling steps could become solid inside a character. Restoration now waits while a living player's body/legs occupy the step's space. It retries after the character clears the surface rather than pushing the body into the stair.

Regression checks cover all 100 non-colliding collars, decorative query flags, no server rider repositioning, local support translation preserving walking input, jumping/landing carry reset, hidden floors not carrying, restoration blocked by an overlapping character, and restoration after clearance. The full default-jump reachability suite still passes. The latest selected music asset remains 134764779929866.

These are verified source/geometry/simulation corrections. Real Roblox controller behaviour, network latency, collision feel and the original reported incident still require checking in Studio. Use the newly downloaded build; previous files do not receive updates automatically.
