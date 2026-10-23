class_name ProgressJson
extends RefCounted
## Sérialisation versionnée de la progression. Une version plus ancienne passe par `migrations`.

## Migrations : clé = version source (int), valeur = Callable(Dictionary) -> Dictionary vers la version suivante.
## Vide : la v1 est la première.
## Migrations : version de départ -> fonction qui transforme le JSON vers la version suivante.
##   1 -> 2 : les niveaux ont été renouvelés ; les parties en cours des anciennes grilles sont abandonnées (les niveaux
##            terminés, les étoiles et les indices sont conservés). Les champs du défi quotidien prennent leurs valeurs par défaut.
##   2 -> 3 : trophées. Champs additifs (compteurs, trophées, trophées vus) : ils prennent leurs valeurs par défaut, et les
##            trophées déjà mérités sont attribués au démarrage (TrophyRules.evaluate).
static var MIGRATIONS := {
	1: func(json: Dictionary) -> Dictionary:
		json["inProgress"] = {}
		return json,
	2: func(json: Dictionary) -> Dictionary:
		return json,
}


static func encode(state: ProgressState) -> String:
	var completed := {}
	for id in state.completed:
		var r: LevelResult = state.completed[id]
		completed[id] = {"stars": r.stars, "elapsedMillis": r.elapsed_millis}
	var in_progress := {}
	for key in state.in_progress:
		var s: GameSnapshot = state.in_progress[key]
		var found := s.found_word_indices.duplicate()
		found.sort()
		in_progress[key] = {
			"found": found, "hinted": s.hinted_word_indices, "wrong": s.wrong_selections,
			"elapsedMillis": s.elapsed_millis,
		}
	var claimed := state.claimed_gift_chapters.duplicate()
	claimed.sort()
	var daily := {}
	for day in state.daily_results:
		var d: LevelResult = state.daily_results[day]
		daily[str(day)] = {"stars": d.stars, "elapsedMillis": d.elapsed_millis}
	var milestones := state.daily_claimed_milestones.duplicate()
	milestones.sort()
	var json := {
		"schemaVersion": ProgressState.CURRENT_SCHEMA,
		"initialHintsGranted": state.initial_hints_granted,
		"hintBalance": state.hint_balance,
		"completed": completed,
		"claimedGiftChapters": claimed,
		"grantedRewardIds": state.granted_reward_ids,
		"perfectStreak": state.perfect_streak,
		"inProgress": in_progress,
		"dailyResults": daily,
		"dailyStreak": state.daily_streak,
		"dailyBestStreak": state.daily_best_streak,
		"dailyLastDay": state.daily_last_day,
		"dailyMilestones": milestones,
		"stats": _sorted_dictionary(state.stats),
		"trophies": _sorted_dictionary(state.trophies),
		"trophiesSeen": _sorted_strings(state.trophies_seen),
	}
	if state.last_praise != Praise.NONE:
		json["lastPraise"] = Praise.key_of(state.last_praise)
	return JSON.stringify(json, "", true)


static func _sorted_dictionary(source: Dictionary) -> Dictionary:
	var keys := source.keys()
	keys.sort()
	var sorted := {}
	for key in keys:
		sorted[String(key)] = int(source[key])
	return sorted


static func _sorted_strings(source: Array[String]) -> Array:
	var copy: Array = source.duplicate()
	copy.sort()
	return copy


## Renvoie un Decoded dont `value` est un ProgressState.
static func decode(text: String, current_version: int = ProgressState.CURRENT_SCHEMA, migrations: Dictionary = MIGRATIONS) -> Decoded:
	var parsed: Variant = JsonUtil.parse_object(text)
	if parsed == null:
		return Decoded.failure("JSON de progression invalide")
	var json: Dictionary = parsed
	if not json.has("schemaVersion"):
		return Decoded.failure("schemaVersion absent")
	var version := JsonUtil.get_int(json, "schemaVersion")
	if version > current_version:
		return Decoded.failure("sauvegarde d'une version plus récente (%d)" % version)
	while version < current_version:
		if not migrations.has(version):
			return Decoded.failure("migration %d -> %d absente" % [version, version + 1])
		json = (migrations[version] as Callable).call(json)
		json["schemaVersion"] = version + 1
		version += 1
	return Decoded.success(_parse(json))


static func _parse(json: Dictionary) -> ProgressState:
	var state := ProgressState.new()
	state.initial_hints_granted = JsonUtil.get_bool(json, "initialHintsGranted", false)
	state.hint_balance = maxi(0, JsonUtil.get_int(json, "hintBalance", 0))
	var completed: Variant = json.get("completed")
	if completed is Dictionary:
		for id in completed:
			var r: Variant = completed[id]
			if r is Dictionary:
				state.completed[String(id)] = LevelResult.new(
					clampi(JsonUtil.get_int(r, "stars", 1), 1, 3), maxi(0, JsonUtil.get_int(r, "elapsedMillis", 0))
				)
	var in_progress: Variant = json.get("inProgress")
	if in_progress is Dictionary:
		for key in in_progress:
			var s: Variant = in_progress[key]
			if s is Dictionary:
				var found := JsonUtil.int_array(s.get("found"))
				var unique: Array[int] = []
				for index in found:
					if not unique.has(index):
						unique.append(index)
				state.in_progress[String(key)] = GameSnapshot.new(
					unique, JsonUtil.int_array(s.get("hinted")),
					JsonUtil.get_int(s, "wrong", 0), JsonUtil.get_int(s, "elapsedMillis", 0)
				)
	var claimed := JsonUtil.int_array(json.get("claimedGiftChapters"))
	for chapter_index in claimed:
		if not state.claimed_gift_chapters.has(chapter_index):
			state.claimed_gift_chapters.append(chapter_index)
	state.granted_reward_ids = JsonUtil.string_array(json.get("grantedRewardIds"))
	state.last_praise = Praise.from_key(JsonUtil.get_string(json, "lastPraise"))
	state.perfect_streak = JsonUtil.get_int(json, "perfectStreak", 0)
	var daily: Variant = json.get("dailyResults")
	if daily is Dictionary:
		for key in daily:
			var entry: Variant = daily[key]
			if entry is Dictionary and String(key).is_valid_int():
				state.daily_results[int(String(key))] = LevelResult.new(
					clampi(JsonUtil.get_int(entry, "stars", 1), 1, 3), maxi(0, JsonUtil.get_int(entry, "elapsedMillis", 0))
				)
	state.daily_streak = maxi(0, JsonUtil.get_int(json, "dailyStreak", 0))
	state.daily_best_streak = maxi(state.daily_streak, JsonUtil.get_int(json, "dailyBestStreak", 0))
	state.daily_last_day = JsonUtil.get_int(json, "dailyLastDay", -1)
	for days in JsonUtil.int_array(json.get("dailyMilestones")):
		if not state.daily_claimed_milestones.has(days):
			state.daily_claimed_milestones.append(days)
	var stats: Variant = json.get("stats")
	if stats is Dictionary:
		for key in stats:
			state.stats[String(key)] = maxi(0, JsonUtil.to_int(stats[key]))
	var trophies: Variant = json.get("trophies")
	if trophies is Dictionary:
		for key in trophies:
			if TrophyCatalog.by_id(String(key)) != null:  # un identifiant inconnu (version plus récente) est ignoré
				state.trophies[String(key)] = maxi(0, JsonUtil.to_int(trophies[key]))
	for id in JsonUtil.string_array(json.get("trophiesSeen")):
		if state.trophies.has(id) and not state.trophies_seen.has(id):
			state.trophies_seen.append(id)
	return state
