class_name InterstitialPolicy
extends RefCounted
## Décide si une interstitielle s'affiche quand le joueur passe au niveau suivant (fonction pure, testée).
## Principe : une chance sur 3 tirée au hasard à chaque passage, MAIS jamais pendant la prise en main, jamais deux annonces
## plein écran rapprochées, jamais juste après une annonce que le joueur a choisie, et moins souvent pour celui qui en regarde déjà beaucoup.
## Les seuils viennent de data/ads_policy.json (AdPolicyConfig).


## Probabilité effective de tirage pour ce passage (0 = jamais).
static func probability(config: AdPolicyConfig, pacing: AdPacing, completed_levels: int, now_ms: int) -> float:
	if not config.interstitial_enabled or completed_levels < config.min_levels_completed:
		return 0.0
	var since_any := pacing.since_last_full_screen(now_ms)
	if since_any != AdPacing.NEVER and since_any < config.min_seconds_between_full_screen_ads * 1000:
		return 0.0
	var since_rewarded := pacing.since_last_rewarded(now_ms)
	if since_rewarded != AdPacing.NEVER and since_rewarded < config.quiet_seconds_after_rewarded * 1000:
		return 0.0
	if pacing.interstitials_in_last_hour(now_ms) >= config.max_interstitials_per_hour:
		return 0.0
	var chance := config.interstitial_probability
	if pacing.rewarded_in_last_hour(now_ms) >= config.rewarded_fatigue_count:
		chance *= config.rewarded_fatigue_factor
	return clampf(chance, 0.0, 1.0)


## `roll` : tirage uniforme dans [0, 1[ (injecté pour les tests).
static func should_show(config: AdPolicyConfig, pacing: AdPacing, completed_levels: int, now_ms: int, roll: float) -> bool:
	return roll < probability(config, pacing, completed_levels, now_ms)
