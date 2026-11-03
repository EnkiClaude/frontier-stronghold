# Changelog

Versions follow `MAJOR.MINOR.PATCH`. While the game is pre-release (0.x), MINOR
goes up for each development phase and PATCH for fixes and playtest feedback.
The version is set in `project.godot` (`application/config/version`), and it
appears in the window title, the HUD and every exported file name.

## v0.3.2 — 2026-11-03 (mobile / web build)
- **Playable in a phone browser** (iPhone Safari, Android Chrome): a single-threaded Web export
  published to GitHub Pages. Add it to your Home Screen for full screen.
- **Touch controls** (switched on automatically on phones and tablets):
  - Tap to select or place; drag to draw lines of walls or belts.
  - One finger pans when no build tool is active; two fingers pan and pinch to zoom.
  - A second finger cancels whatever the first finger started, so pinching never places walls.
  - On-screen **Cancel, Rotate, Sell** (tap or swipe over buildings to sell), **Pause, Speed** and **Menu** buttons.
- **Phone layout:**
  - HUD scale 2.0 by default (up to 2.5 in options).
  - Collapsible resources panel (tap it); smaller minimap.
  - A compact cost line while building; a scrollable info panel.
  - Margins for the notch and rounded corners; a "rotate to landscape" notice in portrait.
- Desktop is unchanged.

## v0.3.1 — 2026-11-03 (playtest feedback: logistics and pacing)
Design: `docs/decisions/ADR-008-supply-drones-belt-routing-waves.md`.
- **Supply drones:** ammo towers refill automatically from the Core or any Storage within 45 tiles.
  - Drones carry up to 5 items per trip.
  - Production volume is now what keeps a defense running.
  - A forward Storage supplies a distant defense line.
  - The tower info panel shows where its supply comes from, or why it has none.
- **Belts deliver into buildings** they point at (Core, Storage, machines, towers, generators, recyclers).
- **Splitter** (Logistics tab): sends items left, straight and right in turn.
- **Belt tunnels:** drag a belt across other belts (or buildings, up to 4 tiles)
  and a tunnel entrance and exit are placed automatically, so the line passes
  under them. The ghost previews the tunnel ends.
- **Waves with gaps:** the constant trickle is now a small wave every 20 s, and
  every assault is followed by a 20 s lull. The status bar shows the countdowns.
- **More ore:** 7 bigger starter patches near the Core (2 iron, 2 copper,
  2 coal, 1 stone). Natural deposits get denser the further east you go.
- **The enemy route preview updates instantly, even while paused**: it includes walls still under construction.

## v0.3.0 — 2026-11-03 (towers, resources, storage, power)
See `docs/decisions/ADR-007-resources-towers-power.md` for the design.

- **Five new towers** (Defense tab), each with its own attack and supply:
  - **Sniper Rifle:** long range, armour-piercing. Needs Rifle Rounds (made from steel).
  - **Flamethrower:** fire cone that also sets enemies burning. Needs Fuel Canisters (coal + iron plate).
  - **Icy Blast:** splash that slows enemies by 45%. Needs Coolant Cells (water + copper plate).
  - **Tesla Coil:** stunning pulse around itself. Needs power.
  - **Lightning Tower:** long-range strike that chains to 3 more enemies. Needs power.
- **Every resource now has a job:**
  - Copper: electric towers and power buildings, plus coolant.
  - Coal: generator fuel, steel and flamethrower fuel.
  - Stone: bricks, as a building material.
  - Water (new Water Pump next to lakes): coolant.
- **Recipes:** the Smelter makes Iron Plate, Copper Plate, Brick or Steel, and the
  Ammo Factory makes Ammo Magazine, Rifle Rounds, Fuel Canister or Coolant Cell.
  Pick the recipe in the info panel; the pipette copies it.
- **Stockpile and Storage:** the Core and Storage buildings hold items that arms
  can put in and take out. Advanced buildings cost credits plus materials from
  the stockpile, and selling refunds materials too. You start with 20 iron
  plates, 10 copper plates and 10 bricks, and excavating rock gives stone.
- **Recycler:** turns delivered items into credits, so your factory can fund your defenses.
- **Power:** Generators burn coal while something needs power, and Power Nodes
  connect them to electric towers. A shortage slows how fast those towers recharge.
- **Status effects:** slowed enemies tint cyan, burning ones orange, and stunned ones get a white ring.
- **Toolbar tabs** (Defense, Logistics, Production, Power; Tab cycles); unaffordable buttons are dimmed.
- The info panel shows recipes, materials (with how many you have), power and storage contents.
- Balance: towers were tuned with `tools/balance_probe.gd` (each tower alone vs 3 minutes of waves).

## v0.2.4 — 2026-11-02 (playtest feedback #3)
- **Fixed: enemies and belt items were invisible on macOS.** They were drawn
  with MultiMesh buffers, which rendered nothing on the player's Mac (the
  HUD counted 56 enemies and 200+ items while the screen showed none).
  - They now use the same drawing path as buildings, culled to the visible area (ADR-006).
  - Enemies get a dark backing disc for contrast and are at least 9 px on screen.
- **Middle-click pipette:** middle-click (or `Q`) on a building to pick it as
  your build tool, with the same rotation. Middle-drag still pans. Middle-click on empty ground drops the tool.
- **Right-click swipe to sell:** hold right-click and swipe to sell everything
  you pass over. The swipe locks to the first row or column you move along, so nothing off the line is removed.
- **Input/output markers only show activity:** they appear when items actually
  move and fade about 1.5 s after the last transfer.
  - Arms highlight the tile they took from (cyan) and the tile they delivered to (green).
  - Drills highlight the tile they're feeding.
  - Machines flash their input and output badges.
  - Empty turrets always show the ammo they need, framed in red.
  - Placement ghosts still preview every input and output.

## v0.2.3 — 2026-11-02 (playtest feedback #2)
- **Belt items are easier to see:** bigger icons, and they never shrink below 6 px on screen.
- **Mining drills output to every tile on their front side.** Before, a 2×2 drill
  only fed one of its two front tiles, so a belt on the other tile never
  received ore. This is the likely reason no items appeared on belts.
- **Belts and arms re-orient for free** when you place them over themselves (e.g. drag a new direction). Items on the belt are kept.
- **Input/output indicators:**
  - Cyan markers show where items go **in**, green markers show where they come **out**.
  - Arms show their pickup and drop tiles, drills mark their front tiles, and machines and turrets show badges for the item they take or make.
  - Placement ghosts show the same markers before you build.
- **Inserter renamed to Robotic Arm**, with clearer help text. It takes items
  from a passing belt without stopping it, so one ammo belt can run past many
  turrets with one arm each. A test covers this.
- **Building near enemies is allowed again** (the no-build radius defaults to 0; it's still configurable in the rules).
- **Nests start less than half as far away** (column 115 instead of 251), and the map leaves room for the frontier to expand later.
- **Preparation time:** 2:45 before the first enemies (was 0:45), with a
  countdown and a **Start waves now [N]** button. Enemy HP growth, unlocks and
  assaults all count from the end of preparation, so skipping never makes
  enemies stronger.
- **Game menu** (Esc, or the Menu button): Resume, Restart, Credits, Quit. It
  pauses the game. **Options:**
  - HUD scale (75–200%)
  - camera pan speed
  - zoom sensitivity
  - show enemy routes
  - fullscreen

  Options are saved to `user://settings.cfg`.
- HUD layout reworked so it fits at large HUD scales: the toolbar wraps, and the countdown sits in the status bar.

## v0.2.2 — 2026-11-02 (futuristic art pass)
- **New look:** self-made sci-fi placeholder art (CC0, generated by
  `tools/art/generate_placeholder_art.gd`):
  - metal deck floor, crystalline rock, glowing ore fields, coolant pools;
  - a reactor Core;
  - wall blocks with energy strips;
  - Chain Gun base with a rotating turret;
  - belt chevrons, drill, smelter, ammo factory and inserter plates;
  - red and purple enemy drones;
  - item icons.
- Terrain tiles use random flips to reduce repetition, and textures use mipmaps so they stay clean when zoomed out.
- Darker, cyan-accented HUD; item icons in the resources panel; pulsing enemy nests.
- Empty towers now show a red tint as well as the flashing ✕.
- **Credits screen** (HUD → Credits) showing `assets/CREDITS.md`.
- Art is optional: every renderer falls back to colours (launch with `--no-art` to compare).
- Asset policy added to `CLAUDE.md`. A test enforces a licence file and a credits entry for every asset pack.
- No third-party packs yet: the asset sites are blocked by the development environment's network policy.

## v0.2.1 — 2026-11-02 (playtest feedback)
- **Fixed: zoom on Mac trackpads and Magic Mouse.** Each small scroll event
  used to count as a full zoom step, which slammed the camera to maximum
  zoom-out. Zoom now scales with the scroll amount. Pinch zooms and
  two-finger swipe pans.
- Zoom-out now stops when the whole map height is visible.
- **HiDPI / Retina:** the game scales correctly instead of rendering at half size.
- **Minimap** (bottom right): enemies (red), buildings, nests and the camera view. Click or drag to move the camera.
- Zoom +/− and **Core [H]** buttons.
- Enemies stay at least 7 px on screen, so they're visible when zoomed out.
- **Resources panel:** credits, items in the factory with production per minute, and the tower ammo summary (empty or low towers).
- **Info panel:** full details of the selected building, or of the building
  you're about to place. For towers that's damage and type, fire rate, DPS,
  range, targeting, ammo type and rounds per magazine, rounds loaded, kills
  and rounds fired.
- Toolbar buttons show the name, hotkey and cost, with descriptions as tooltips.
- Balance: starting credits 400 → **1500**; first enemies arrive after **45 s** (was 25 s), with a countdown.

## v0.2.0 — 2026-11-02 (Phase 1.5: supply slice)
- Belts, inserters, mining drills, smelter and ammo factory. Chain Guns use ammo.
- Fixed drag-to-place only placing one structure.

## v0.1.0 — 2026-11-02 (Phase 1: maze prototype)
- Walls, Chain Gun, flow-field pathing with route validation, sell/move, excavation, assaults.
