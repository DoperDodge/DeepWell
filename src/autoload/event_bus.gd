## Global signal hub (PLAN.md §5.2).
## RULE: no system may hold a direct reference to another system.
## Everything communicates through these signals. Emitters know nothing about
## listeners; listeners know nothing about emitters.
extends Node

# --- Run lifecycle ---
@warning_ignore_start("unused_signal")
signal run_started(seed_value: int)
signal run_ended(outcome: StringName) # &"death" | &"descend" | &"quit"
signal player_spawned(player: Node3D)
signal player_died(cause: String, floor_index: int, position: Vector3)
signal player_moved_floor(from_floor: int, to_floor: int)

# --- Perception (PLAN §9) ---
signal noise_emitted(position: Vector3, loudness: float, source: Node, tags: Array)
signal player_gaze_entered(target: Node3D)
signal player_gaze_exited(target: Node3D)
signal player_blinked(duration: float)

# --- Survival (PLAN §10) ---
signal need_changed(need_id: StringName, value: float)
signal moodle_changed(moodle_id: StringName, level: int)
signal body_part_damaged(part: StringName, damage_type: StringName, amount: float)
signal body_part_treated(part: StringName, treatment: StringName)
signal sanity_changed(current: float, delta: float)
signal player_health_changed(total: float)

# --- Facility ---
signal power_state_changed(zone_id: StringName, powered: bool)
signal alarm_level_changed(level: int)
signal door_state_changed(door_id: StringName, state: int)
signal containment_breached(scp_id: StringName)
signal pa_announcement(text: String)
signal floor_generated(floor_index: int)

# --- Inventory / items ---
signal inventory_changed
signal item_picked_up(item_id: StringName)
signal item_consumed(item_id: StringName)
signal keycard_acquired(level: int)
signal clearance_changed(level: int)

# --- Progression / lore ---
signal skill_xp_gained(skill_id: StringName, amount: float)
signal document_read(document_id: StringName)
signal document_collected(document_id: StringName)
signal document_open_requested(document_id: StringName)
signal scp_witnessed(designation: StringName)  # feeds the Anomaly Log (PLAN §20.5)
signal incident_logged(text: String)           # facility incident reports (914 uses, breaches)

# --- UI ---
signal toast(text: String)                     # transient HUD line
signal restart_requested(keep_site: bool)      # death screen -> next D-Class
signal menu_requested                          # back to main menu
signal subtitle(speaker: String, text: String)
signal ui_screen_changed(screen: StringName)
@warning_ignore_restore("unused_signal")
