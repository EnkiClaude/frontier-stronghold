extends Node
## Global event bus (autoload "Events").
##
## For loose, cross-system notifications (UI, audio, effects). Simulation-critical
## data flows through direct calls on the simulation objects, never through here.

@warning_ignore("unused_signal")
signal world_generated(width: int, height: int)

@warning_ignore("unused_signal")
signal sim_speed_changed(speed: float, paused: bool)
