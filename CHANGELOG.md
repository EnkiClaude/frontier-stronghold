# Changelog

Versions follow `MAJOR.MINOR.PATCH`. While the game is pre-release (0.x), MINOR
goes up for each development phase and PATCH for fixes and playtest feedback.
The version is set in `project.godot` (`application/config/version`), and it
appears in the window title, the HUD and every exported file name.

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
