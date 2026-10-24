class_name GodotAudioManager
extends AudioManager
## Sons courts préchargés (un lecteur polyphonique par son : faible latence, flux limités pour éviter la
## saturation) et musique d'ambiance en boucle sans coupure (boucle de l'import OGG, échantillon près).
## Un fichier absent n'est jamais une erreur : le praise retombe sur le son de réussite générique.

const MUSIC_PATH := "res://assets/audio/music/music_background.ogg"
## Gain maximal de la musique (curseur à fond). Le fichier est normalisé à -20 LUFS (boucle sans couture, voir
## docs/AUDIO.md) ; au curseur par défaut (0,6) le gain vaut 0,55 × 0,36 ≈ 0,2 (-14 dB), soit ≈ -34 LUFS : environ 9 dB sous
## les effets sonores à leur volume par défaut (60 %) — une ambiance de fond qui n'écrase jamais les effets ni les voix.
const MUSIC_MAX_GAIN := 0.55
## Atténuation de la musique (bus « Music ») pendant les voix de félicitations et les jingles de victoire.
const DUCK_DB := -7.0
const DUCK_ATTACK_SECONDS := 0.12
const DUCK_RELEASE_SECONDS := 0.9
const DUCK_JINGLE_SECONDS := 1.4
## Sons qui font baisser la musique le temps de leur diffusion.
const DUCKING_SOUNDS: Array[int] = [Sound.SUCCESS_GENERIC, Sound.GIFT, Sound.VICTORY]
const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
const POLYPHONY := 4

var _sound_players: Dictionary = {}  ## Sound (int) -> AudioStreamPlayer
var _praise_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _praise_map: PraiseMap = PraiseMap.empty()
var _praise_streams: Dictionary = {}  ## chemin -> AudioStream
var _music_enabled := true
var _music_volume := AppSettings.DEFAULT_MUSIC_VOLUME
var _app_in_background := false
var _loaded := false
var _duck_tween: Tween


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)


func is_loaded() -> bool:
	return _loaded


## Précharge tous les sons ; `on_progress` reçoit 0..1. Idempotent. Les échecs sont tolérés.
func preload_all(on_progress: Callable = Callable()) -> void:
	if _loaded:
		return
	var text := FileAccess.get_file_as_string(PraiseMap.FILE) if FileAccess.file_exists(PraiseMap.FILE) else ""
	var parsed := PraiseMap.parse(text)
	_praise_map = parsed if parsed != null else PraiseMap.empty()

	var paths: Array[String] = []
	for sound in UiSounds.all_sounds():
		paths.append(UiSounds.asset_path(sound))
	paths.append_array(_praise_map.all_asset_paths())
	var done := 0
	for sound in UiSounds.all_sounds():
		var stream := _load_stream(UiSounds.asset_path(sound))
		if stream != null:
			var player := AudioStreamPlayer.new()
			player.stream = stream
			player.bus = SFX_BUS
			player.max_polyphony = POLYPHONY
			player.volume_db = linear_to_db(UiSounds.volume_for(sound))
			add_child(player)
			_sound_players[sound] = player
		done += 1
		if on_progress.is_valid():
			on_progress.call(float(done) / paths.size())
	for path in _praise_map.all_asset_paths():
		var stream := _load_stream(path)
		if stream != null:
			_praise_streams[path] = stream
		done += 1
		if on_progress.is_valid():
			on_progress.call(float(done) / paths.size())
	_praise_player = AudioStreamPlayer.new()
	_praise_player.bus = SFX_BUS
	add_child(_praise_player)
	if ResourceLoader.exists(MUSIC_PATH):
		_music_player = AudioStreamPlayer.new()
		_music_player.stream = load(MUSIC_PATH)
		_music_player.bus = MUSIC_BUS
		_music_player.volume_db = linear_to_db(maxf(music_gain(_music_volume), 0.0001))
		add_child(_music_player)
	_loaded = true
	_refresh_music()


func play(sound: int) -> void:
	var player: AudioStreamPlayer = _sound_players.get(sound)
	if player != null:
		player.play()
		if DUCKING_SOUNDS.has(sound):
			duck_music(DUCK_JINGLE_SECONDS)


func play_praise(praise: int, language: int) -> void:
	var voice := _praise_map.resolve(praise, language)
	var stream: AudioStream = _praise_streams.get(voice.asset_path) if voice != null else null
	if stream == null:
		play(Sound.SUCCESS_GENERIC)  # repli : jamais de silence sur une victoire
		return
	_praise_player.stream = stream
	_praise_player.volume_db = linear_to_db(voice.volume)
	_praise_player.play()
	duck_music(stream.get_length())


## Fait baisser la musique (bus « Music ») le temps de `hold_seconds`, puis la rend en douceur : une voix ou un jingle reste
## toujours bien audible, sans couper l'ambiance. Un nouvel appel pendant l'atténuation la prolonge sans à-coup.
func duck_music(hold_seconds: float) -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus < 0 or not is_inside_tree() or _music_player == null or not _music_player.playing:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var set_db := func(db: float) -> void: AudioServer.set_bus_volume_db(bus, db)
	_duck_tween = create_tween()
	_duck_tween.tween_method(set_db, AudioServer.get_bus_volume_db(bus), DUCK_DB, DUCK_ATTACK_SECONDS)
	_duck_tween.tween_interval(maxf(hold_seconds, 0.0))
	_duck_tween.tween_method(set_db, DUCK_DB, 0.0, DUCK_RELEASE_SECONDS)


func set_sound_effects_enabled(enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not enabled)


## Volume du curseur (0..1) -> gain linéaire (même courbe quadratique que la musique : le bas du curseur reste fin ;
## 100 % = niveau d'origine des effets).
static func sfx_gain(volume: float) -> float:
	return pow(clampf(volume, 0.0, 1.0), 2.0)


## Volume des effets sonores : règle le bus « SFX » (tous les effets et les voix de félicitations passent par lui).
func set_sfx_volume(volume: float) -> void:
	var bus := AudioServer.get_bus_index(SFX_BUS)
	if bus < 0:
		return
	var clamped := clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus, clamped <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_gain(clamped), 0.0001)))


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	_refresh_music()


## Volume du curseur (0..1) -> gain linéaire perceptif (courbe quadratique : le bas du curseur reste fin).
static func music_gain(volume: float) -> float:
	return MUSIC_MAX_GAIN * pow(clampf(volume, 0.0, 1.0), 2.0)


func set_music_volume(volume: float) -> void:
	_music_volume = clampf(volume, 0.0, 1.0)
	_music_enabled = _music_volume > 0.001
	if _music_player != null:
		_music_player.volume_db = linear_to_db(maxf(music_gain(_music_volume), 0.0001))
	_refresh_music()

func get_music_volume() -> float:
	return _music_volume


## Appli en arrière-plan : la musique se met en pause (jamais de son hors de l'écran).
func on_app_stopped() -> void:
	_app_in_background = true
	if _music_player != null:
		_music_player.stream_paused = true


func on_app_started() -> void:
	_app_in_background = false
	if _music_player != null:
		_music_player.stream_paused = false
	_refresh_music()


func _refresh_music() -> void:
	if _music_player == null:
		return
	if not _music_enabled:
		_music_player.stop()
	elif not _app_in_background and not _music_player.playing:
		_music_player.play()


func _load_stream(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


static func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
