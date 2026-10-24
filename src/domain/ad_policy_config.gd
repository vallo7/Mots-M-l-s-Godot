class_name AdPolicyConfig
extends RefCounted
## Réglages du rythme des publicités, lus dans data/ads_policy.json. Tolérant : un fichier absent, illisible ou une valeur
## hors limites retombe sur les valeurs par défaut (jamais d'erreur, jamais de pub trop fréquente à cause d'une faute de frappe).

const PATH := "res://data/ads_policy.json"

## Interstitielle au passage au niveau suivant.
var interstitial_enabled := true
## Probabilité de tirage à chaque passage (1 chance sur 3, tirée au hasard à chaque fois).
var interstitial_probability := 1.0 / 3.0
## Aucune interstitielle tant que le joueur n'a pas terminé ce nombre de niveaux (prise en main sans publicité).
var min_levels_completed := 4
## Écart minimal entre deux annonces plein écran, toutes sortes confondues (interstitielle, récompensée, de retour).
var min_seconds_between_full_screen_ads := 90
var max_interstitials_per_hour := 12
## Pas d'interstitielle juste après une récompensée : le joueur vient de choisir de regarder une pub.
var quiet_seconds_after_rewarded := 120
## Un joueur qui regarde souvent des récompensées (≥ `rewarded_fatigue_count` dans l'heure) voit moins d'interstitielles.
var rewarded_fatigue_count := 3
var rewarded_fatigue_factor := 0.5
## « Doubler la récompense » (cadeau de chapitre, indices du défi du jour) contre une publicité récompensée.
var double_reward_enabled := true
## Rechargement des annonces : délais croissants entre deux essais après un échec, nombre d'échecs de suite toléré.
var retry_delays_seconds: Array[float] = [4.0, 10.0, 30.0, 60.0, 120.0]
var max_consecutive_failures := 8
## Une interstitielle chargée expire au bout d'une heure : on la recharge avant.
var interstitial_ttl_minutes := 50
## Public « tout public » : contenu publicitaire limité à PG (G = très strict, T/MA = plus large).
var max_ad_content_rating := "PG"


static func defaults() -> AdPolicyConfig:
	return AdPolicyConfig.new()


static func load_file(path: String = PATH) -> AdPolicyConfig:
	if not FileAccess.file_exists(path):
		return defaults()
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> AdPolicyConfig:
	var config := AdPolicyConfig.new()
	var parsed: Variant = JsonUtil.parse_object(text)
	if parsed == null:
		return config
	var root: Dictionary = parsed
	var interstitial: Dictionary = _section(root, "interstitial")
	config.interstitial_enabled = JsonUtil.get_bool(interstitial, "enabled", config.interstitial_enabled)
	config.interstitial_probability = _number(interstitial, "probability", config.interstitial_probability, 0.0, 1.0)
	config.min_levels_completed = int(_number(interstitial, "min_levels_completed", config.min_levels_completed, 0.0, 1000.0))
	config.min_seconds_between_full_screen_ads = int(_number(interstitial, "min_seconds_between_full_screen_ads", config.min_seconds_between_full_screen_ads, 15.0, 3600.0))
	config.max_interstitials_per_hour = int(_number(interstitial, "max_per_hour", config.max_interstitials_per_hour, 0.0, 120.0))
	config.quiet_seconds_after_rewarded = int(_number(interstitial, "quiet_seconds_after_rewarded", config.quiet_seconds_after_rewarded, 0.0, 3600.0))
	config.rewarded_fatigue_count = int(_number(interstitial, "fatigue_rewarded_count", config.rewarded_fatigue_count, 1.0, 100.0))
	config.rewarded_fatigue_factor = _number(interstitial, "fatigue_factor", config.rewarded_fatigue_factor, 0.0, 1.0)
	config.double_reward_enabled = JsonUtil.get_bool(_section(root, "rewarded"), "double_reward_enabled", config.double_reward_enabled)
	var loading: Dictionary = _section(root, "loading")
	var delays: Variant = loading.get("retry_delays_seconds")
	if delays is Array and not (delays as Array).is_empty():
		var parsed_delays: Array[float] = []
		for value in delays:
			if value is float or value is int:
				parsed_delays.append(clampf(float(value), 1.0, 600.0))
		if not parsed_delays.is_empty():
			config.retry_delays_seconds = parsed_delays
	config.max_consecutive_failures = int(_number(loading, "max_consecutive_failures", config.max_consecutive_failures, 1.0, 100.0))
	config.interstitial_ttl_minutes = int(_number(loading, "interstitial_ttl_minutes", config.interstitial_ttl_minutes, 5.0, 55.0))
	var rating := JsonUtil.get_string(_section(root, "content"), "max_ad_content_rating", config.max_ad_content_rating).strip_edges().to_upper()
	if ["G", "PG", "T", "MA"].has(rating):
		config.max_ad_content_rating = rating
	return config


## Délai avant le prochain essai de chargement après `failures` échecs de suite (le dernier délai se répète).
func retry_delay(failures: int) -> float:
	return retry_delays_seconds[clampi(failures - 1, 0, retry_delays_seconds.size() - 1)]


static func _section(root: Dictionary, key: String) -> Dictionary:
	var value: Variant = root.get(key)
	return value if value is Dictionary else {}


static func _number(source: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value: Variant = source.get(key)
	if value is float or value is int:
		return clampf(float(value), low, high)
	return fallback
