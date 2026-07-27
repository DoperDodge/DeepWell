## Audio playback + the procedural sound forge (PLAN §14, adapted).
## This project ships ZERO recorded audio: every effect, drone, and chime is
## synthesized here at startup from noise, sines, and filters. That keeps the
## repository text-only and the CC BY-SA release unencumbered. Replace any
## entry with a real CC0 sample later by editing _build_library().
extends Node

const MIX_RATE := 22050

var _library: Dictionary = {} # StringName -> AudioStreamWAV
var _ambience_players: Dictionary = {} # StringName -> AudioStreamPlayer
var _synth_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_synth_rng.seed = 1337 # fixed: audio must not consume run RNG streams
	_setup_buses()
	_build_library()

# ---------------------------------------------------------------- playback

func play_3d(sound: StringName, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 32.0) -> void:
	var s: AudioStreamWAV = _library.get(sound)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.unit_size = 6.0
	p.attenuation_filter_cutoff_hz = 12000.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

func play_ui(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStreamWAV = _library.get(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = &"UI"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## Looping room tone. Fades in; call stop_ambience to fade out.
func start_ambience(sound: StringName, volume_db: float = -12.0) -> void:
	if _ambience_players.has(sound):
		return
	var s: AudioStreamWAV = _library.get(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = &"Ambience"
	p.volume_db = -60.0
	add_child(p)
	p.play()
	_ambience_players[sound] = p
	var tw := create_tween()
	tw.tween_property(p, "volume_db", volume_db, 2.5)

func stop_ambience(sound: StringName = &"") -> void:
	var keys: Array = [sound] if sound != &"" else _ambience_players.keys()
	for k in keys:
		var p: AudioStreamPlayer = _ambience_players.get(k)
		if p == null:
			continue
		_ambience_players.erase(k)
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, 1.5)
		tw.tween_callback(p.queue_free)

func stop_all_ambience() -> void:
	stop_ambience()

func has_sound(sound: StringName) -> bool:
	return _library.has(sound)

# ---------------------------------------------------------------- buses

func _setup_buses() -> void:
	for bus_name in ["SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")
	# Small-room reverb on SFX sells "interior" for free.
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx != -1 and AudioServer.get_bus_effect_count(sfx) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.45
		reverb.damping = 0.6
		reverb.wet = 0.18
		AudioServer.add_bus_effect(sfx, reverb)

# ---------------------------------------------------------------- synthesis

func _build_library() -> void:
	# Footsteps: concrete (4 variants) and metal grating (2 variants).
	for i in 4:
		_library[StringName("footstep_concrete_%d" % i)] = _make_footstep(0.35 + 0.08 * i, false)
	for i in 2:
		_library[StringName("footstep_metal_%d" % i)] = _make_footstep(0.5 + 0.1 * i, true)
	_library[&"door_open"] = _make_door_open()
	_library[&"door_close"] = _make_door_close()
	_library[&"door_locked"] = _make_denied_click()
	_library[&"door_pry"] = _make_metal_groan()
	_library[&"keycard_ok"] = _make_beeps([880.0, 1318.0], 0.09)
	_library[&"keycard_deny"] = _make_buzz()
	_library[&"pickup"] = _make_pickup()
	_library[&"paper"] = _make_paper()
	_library[&"ui_click"] = _make_click()
	_library[&"eat"] = _make_munch()
	_library[&"drink"] = _make_gulp()
	_library[&"bandage"] = _make_cloth()
	_library[&"stone_drag"] = _make_stone_drag()
	_library[&"neck_snap"] = _make_snap()
	_library[&"heartbeat"] = _make_heartbeat()
	_library[&"pa_chime"] = _make_beeps([659.0, 880.0, 987.0], 0.16)
	_library[&"machine_run"] = _make_machine()
	_library[&"squeak"] = _make_squeak()
	_library[&"thud"] = _make_thud()
	_library[&"whisper"] = _make_whisper()
	_library[&"drone_lcz"] = _make_drone(58.0, 0.5, true)
	_library[&"fluoro_hum"] = _make_hum()
	_library[&"alarm"] = _make_alarm()
	_library[&"rumble_low"] = _make_drone(31.0, 0.8, true)
	_library[&"groan"] = _make_groan()
	_library[&"cough"] = _make_cough()
	_library[&"shriek"] = _make_shriek()
	_library[&"wheeze"] = _make_wheeze()
	_library[&"drone_entrance"] = _make_hum2()
	_library[&"drone_admin"] = _make_drone(74.0, 0.35, true)

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * MIX_RATE))
	return b

func _to_wav(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav

func _add_noise(buf: PackedFloat32Array, amp: float) -> void:
	for i in buf.size():
		buf[i] += _synth_rng.randf_range(-amp, amp)

func _add_brown(buf: PackedFloat32Array, amp: float) -> void:
	var acc := 0.0
	for i in buf.size():
		acc += _synth_rng.randf_range(-1.0, 1.0) * 0.02
		acc = clampf(acc, -1.0, 1.0) * 0.998
		buf[i] += acc * amp

func _add_sine(buf: PackedFloat32Array, freq: float, amp: float, freq_end: float = -1.0) -> void:
	var phase := 0.0
	var f := freq
	var n := buf.size()
	for i in n:
		if freq_end > 0.0:
			f = lerpf(freq, freq_end, float(i) / n)
		phase += TAU * f / MIX_RATE
		buf[i] += sin(phase) * amp

func _lowpass(buf: PackedFloat32Array, cutoff_hz: float) -> void:
	var rc := 1.0 / (TAU * cutoff_hz)
	var dt := 1.0 / MIX_RATE
	var a := dt / (rc + dt)
	var y := 0.0
	for i in buf.size():
		y += a * (buf[i] - y)
		buf[i] = y

func _highpass(buf: PackedFloat32Array, cutoff_hz: float) -> void:
	var rc := 1.0 / (TAU * cutoff_hz)
	var dt := 1.0 / MIX_RATE
	var a := rc / (rc + dt)
	var y := 0.0
	var prev := 0.0
	for i in buf.size():
		var x := buf[i]
		y = a * (y + x - prev)
		prev = x
		buf[i] = y

## Attack-decay envelope; decay_pow > 1 = snappier tail.
func _envelope(buf: PackedFloat32Array, attack_s: float, decay_pow: float) -> void:
	var n := buf.size()
	var attack_n := maxi(int(attack_s * MIX_RATE), 1)
	for i in n:
		var env := 1.0
		if i < attack_n:
			env = float(i) / attack_n
		else:
			var t := float(i - attack_n) / maxf(float(n - attack_n), 1.0)
			env = pow(1.0 - t, decay_pow)
		buf[i] *= env

func _tremolo(buf: PackedFloat32Array, rate_hz: float, depth: float) -> void:
	for i in buf.size():
		buf[i] *= 1.0 - depth * 0.5 * (1.0 + sin(TAU * rate_hz * i / MIX_RATE))

func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at_s: float, gain: float = 1.0) -> void:
	var off := int(at_s * MIX_RATE)
	for i in src.size():
		var j := off + i
		if j >= 0 and j < dst.size():
			dst[j] += src[i] * gain

# --- individual sounds ---

func _make_footstep(brightness: float, metallic: bool) -> AudioStreamWAV:
	var b := _buf(0.16)
	_add_noise(b, 0.9)
	_lowpass(b, 900.0 + brightness * 2200.0)
	_envelope(b, 0.004, 5.0)
	var thump := _buf(0.12)
	_add_sine(thump, 72.0, 0.5, 48.0)
	_envelope(thump, 0.002, 6.0)
	_mix(b, thump, 0.0)
	if metallic:
		var ring := _buf(0.3)
		_add_sine(ring, 1370.0, 0.06)
		_add_sine(ring, 2210.0, 0.04)
		_envelope(ring, 0.001, 8.0)
		_mix(b, ring, 0.01)
	return _to_wav(b)

func _make_door_open() -> AudioStreamWAV:
	var b := _buf(0.7)
	_add_noise(b, 0.35)
	_highpass(b, 300.0)
	_lowpass(b, 2400.0)
	_envelope(b, 0.15, 1.6)
	var servo := _buf(0.6)
	_add_sine(servo, 170.0, 0.18, 110.0)
	_envelope(servo, 0.1, 1.5)
	_mix(b, servo, 0.05)
	return _to_wav(b)

func _make_door_close() -> AudioStreamWAV:
	var b := _buf(0.35)
	_add_noise(b, 0.7)
	_lowpass(b, 700.0)
	_envelope(b, 0.002, 5.0)
	var boom := _buf(0.3)
	_add_sine(boom, 58.0, 0.6, 40.0)
	_envelope(boom, 0.002, 4.0)
	_mix(b, boom, 0.0)
	return _to_wav(b)

func _make_denied_click() -> AudioStreamWAV:
	var b := _buf(0.28)
	var c := _buf(0.03)
	_add_noise(c, 0.8)
	_highpass(c, 1500.0)
	_envelope(c, 0.001, 6.0)
	_mix(b, c, 0.0)
	_mix(b, c, 0.12)
	return _to_wav(b)

func _make_metal_groan() -> AudioStreamWAV:
	var b := _buf(1.4)
	_add_sine(b, 88.0, 0.25)
	_add_sine(b, 91.5, 0.22)
	_add_sine(b, 174.0, 0.12)
	_add_sine(b, 233.0, 0.07)
	_tremolo(b, 6.5, 0.7)
	_envelope(b, 0.35, 1.8)
	var scrape := _buf(1.2)
	_add_noise(scrape, 0.25)
	_lowpass(scrape, 500.0)
	_tremolo(scrape, 11.0, 0.9)
	_envelope(scrape, 0.3, 2.0)
	_mix(b, scrape, 0.1)
	return _to_wav(b)

func _make_beeps(freqs: Array, each_s: float) -> AudioStreamWAV:
	var total := each_s * freqs.size() + 0.08
	var b := _buf(total)
	for i in freqs.size():
		var t := _buf(each_s)
		_add_sine(t, freqs[i], 0.35)
		_envelope(t, 0.005, 2.0)
		_mix(b, t, each_s * i)
	return _to_wav(b)

func _make_buzz() -> AudioStreamWAV:
	var b := _buf(0.32)
	_add_sine(b, 196.0, 0.3)
	_add_sine(b, 392.0, 0.18)
	_add_sine(b, 588.0, 0.08)
	_tremolo(b, 30.0, 0.6)
	_envelope(b, 0.01, 1.5)
	return _to_wav(b)

func _make_pickup() -> AudioStreamWAV:
	var b := _buf(0.14)
	_add_noise(b, 0.5)
	_highpass(b, 900.0)
	_lowpass(b, 5200.0)
	_envelope(b, 0.003, 4.5)
	return _to_wav(b)

func _make_paper() -> AudioStreamWAV:
	var b := _buf(0.4)
	_add_noise(b, 0.4)
	_highpass(b, 1200.0)
	_tremolo(b, 17.0, 0.8)
	_envelope(b, 0.03, 2.2)
	return _to_wav(b)

func _make_click() -> AudioStreamWAV:
	var b := _buf(0.05)
	_add_noise(b, 0.6)
	_highpass(b, 2000.0)
	_envelope(b, 0.001, 7.0)
	return _to_wav(b)

func _make_munch() -> AudioStreamWAV:
	var b := _buf(0.9)
	for i in 3:
		var c := _buf(0.16)
		_add_noise(c, 0.55)
		_lowpass(c, 1300.0)
		_envelope(c, 0.01, 3.0)
		_mix(b, c, 0.28 * i)
	return _to_wav(b)

func _make_gulp() -> AudioStreamWAV:
	var b := _buf(0.6)
	for i in 2:
		var g := _buf(0.18)
		_add_sine(g, 150.0, 0.4, 90.0)
		_envelope(g, 0.02, 3.0)
		_mix(b, g, 0.26 * i)
	return _to_wav(b)

func _make_cloth() -> AudioStreamWAV:
	var b := _buf(0.8)
	_add_noise(b, 0.3)
	_lowpass(b, 2600.0)
	_highpass(b, 500.0)
	_tremolo(b, 9.0, 0.85)
	_envelope(b, 0.08, 1.6)
	return _to_wav(b)

func _make_stone_drag() -> AudioStreamWAV:
	var b := _buf(0.4)
	_add_brown(b, 1.4)
	_lowpass(b, 420.0)
	_tremolo(b, 23.0, 0.5)
	_envelope(b, 0.01, 2.2)
	var grind := _buf(0.35)
	_add_sine(grind, 93.0, 0.3)
	_add_sine(grind, 137.0, 0.2)
	_tremolo(grind, 31.0, 0.8)
	_envelope(grind, 0.01, 3.0)
	_mix(b, grind, 0.02)
	return _to_wav(b)

func _make_snap() -> AudioStreamWAV:
	var b := _buf(0.5)
	var crack := _buf(0.04)
	_add_noise(crack, 1.0)
	_highpass(crack, 800.0)
	_envelope(crack, 0.0005, 8.0)
	_mix(b, crack, 0.0)
	var thump := _buf(0.4)
	_add_sine(thump, 60.0, 0.8, 35.0)
	_envelope(thump, 0.004, 3.5)
	_mix(b, thump, 0.02)
	return _to_wav(b)

func _make_heartbeat() -> AudioStreamWAV:
	var b := _buf(0.6)
	for pair in [[0.0, 0.7], [0.17, 0.5]]:
		var t := _buf(0.16)
		_add_sine(t, 58.0, pair[1], 42.0)
		_envelope(t, 0.008, 4.0)
		_mix(b, t, pair[0])
	return _to_wav(b)

func _make_machine() -> AudioStreamWAV:
	var b := _buf(3.2)
	_add_sine(b, 49.0, 0.2)
	_add_sine(b, 98.0, 0.12)
	_tremolo(b, 3.0, 0.3)
	for i in 22:
		var c := _buf(0.03)
		_add_noise(c, 0.7)
		_highpass(c, 1000.0)
		_envelope(c, 0.001, 6.0)
		_mix(b, c, 0.12 + i * 0.13, 0.5)
	_envelope(b, 0.3, 1.2)
	return _to_wav(b)

func _make_squeak() -> AudioStreamWAV:
	var b := _buf(0.35)
	_add_sine(b, 900.0, 0.3, 1500.0)
	_tremolo(b, 25.0, 0.4)
	_envelope(b, 0.03, 2.5)
	return _to_wav(b)

func _make_thud() -> AudioStreamWAV:
	var b := _buf(0.3)
	_add_noise(b, 0.5)
	_lowpass(b, 500.0)
	_envelope(b, 0.003, 5.0)
	var boom := _buf(0.25)
	_add_sine(boom, 65.0, 0.5, 45.0)
	_envelope(boom, 0.003, 4.0)
	_mix(b, boom, 0.0)
	return _to_wav(b)

func _make_whisper() -> AudioStreamWAV:
	var b := _buf(2.2)
	_add_noise(b, 0.22)
	_highpass(b, 1400.0)
	_lowpass(b, 3800.0)
	_tremolo(b, 4.2, 0.9)
	_tremolo(b, 0.7, 0.6)
	_envelope(b, 0.6, 1.4)
	return _to_wav(b)

func _make_drone(base_hz: float, noise_amt: float, loop: bool) -> AudioStreamWAV:
	var b := _buf(6.0)
	_add_sine(b, base_hz, 0.14)
	_add_sine(b, base_hz * 2.01, 0.07)
	_add_sine(b, base_hz * 2.99, 0.035)
	var wash := _buf(6.0)
	_add_brown(wash, noise_amt)
	_lowpass(wash, 240.0)
	_mix(b, wash, 0.0, 0.5)
	_tremolo(b, 0.13, 0.35)
	return _to_wav(b, loop)

func _make_hum() -> AudioStreamWAV:
	var b := _buf(2.0)
	_add_sine(b, 100.0, 0.08)
	_add_sine(b, 200.0, 0.045)
	_add_sine(b, 300.0, 0.018)
	var fizz := _buf(2.0)
	_add_noise(fizz, 0.05)
	_highpass(fizz, 4000.0)
	_mix(b, fizz, 0.0, 0.4)
	return _to_wav(b, true)

func _make_groan() -> AudioStreamWAV:
	var b := _buf(1.5)
	_add_sine(b, 82.0, 0.3, 64.0)
	_add_sine(b, 165.0, 0.14, 130.0)
	_add_sine(b, 249.0, 0.06, 200.0)
	var breath := _buf(1.5)
	_add_noise(breath, 0.15)
	_lowpass(breath, 900.0)
	_mix(b, breath, 0.0, 0.6)
	_tremolo(b, 5.5, 0.35)
	_envelope(b, 0.25, 1.6)
	return _to_wav(b)

func _make_cough() -> AudioStreamWAV:
	var b := _buf(0.8)
	for i in 2:
		var c := _buf(0.22)
		_add_noise(c, 0.9)
		_lowpass(c, 1600.0)
		_add_sine(c, 130.0, 0.3, 90.0)
		_envelope(c, 0.004, 4.0)
		_mix(b, c, 0.3 * i)
	return _to_wav(b)

func _make_shriek() -> AudioStreamWAV:
	var b := _buf(0.9)
	_add_sine(b, 1900.0, 0.22, 2600.0)
	_add_sine(b, 950.0, 0.18, 1400.0)
	var hiss := _buf(0.9)
	_add_noise(hiss, 0.4)
	_highpass(hiss, 2500.0)
	_mix(b, hiss, 0.0, 0.6)
	_tremolo(b, 22.0, 0.5)
	_envelope(b, 0.02, 2.2)
	return _to_wav(b)

func _make_wheeze() -> AudioStreamWAV:
	var b := _buf(1.1)
	_add_noise(b, 0.3)
	_highpass(b, 700.0)
	_lowpass(b, 2400.0)
	_tremolo(b, 2.6, 0.9)
	_envelope(b, 0.2, 1.5)
	return _to_wav(b)

func _make_hum2() -> AudioStreamWAV:
	var b := _buf(4.0)
	_add_sine(b, 120.0, 0.06)
	_add_sine(b, 240.0, 0.03)
	var air := _buf(4.0)
	_add_brown(air, 0.3)
	_lowpass(air, 500.0)
	_mix(b, air, 0.0, 0.4)
	return _to_wav(b, true)

func _make_alarm() -> AudioStreamWAV:
	var b := _buf(1.6)
	var up := _buf(0.75)
	_add_sine(up, 520.0, 0.3, 760.0)
	_envelope(up, 0.03, 1.1)
	_mix(b, up, 0.0)
	_mix(b, up, 0.8)
	return _to_wav(b, true)
