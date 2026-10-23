class_name AdProvider
extends RefCounted
## Fournisseur de publicités (Google Mobile Ads aujourd'hui, remplaçable). Ne bloque jamais le jeu.
## Interface : surchargée par les implémentations.


## Identifiant du fournisseur actif : « none », « simulated » (annonces de test simulées) ou « admob » (vrai SDK Google).
func provider_id() -> String:
	return "none"


## UnavailableReason.NONE = une publicité récompensée est prête ; sinon la raison.
func rewarded_unavailable_reason() -> int:
	return UnavailableReason.NOT_LOADED


## Asynchrone (await). Renvoie un RewardedAdResult.
func show_rewarded() -> RewardedAdResult:
	return RewardedAdResult.unavailable(UnavailableReason.NOT_LOADED)


## Publicité de retour dans l'appli. Asynchrone. Renvoie true si elle a effectivement été affichée.
func show_return_ad_if_ready() -> bool:
	return false


## Vrai tant qu'une publicité plein écran est à l'écran (le retour qui suit n'est pas un retour « joueur »).
func is_full_screen_ad_showing() -> bool:
	return false


## Affiche ou retire la bannière du bas de l'écran de jeu (zone réservée de 50 dp ; sans effet si indisponible).
func set_banner_visible(_visible: bool) -> void:
	pass


## Vrai si la région impose d'offrir l'accès aux choix de confidentialité des publicités.
func privacy_options_required() -> bool:
	return false


## Affiche le formulaire des choix de confidentialité (asynchrone).
func show_privacy_options() -> void:
	pass
