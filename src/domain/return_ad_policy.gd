class_name ReturnAdPolicy
extends RefCounted
## Publicité de retour dans l'application : proposée quand le joueur revient dans le jeu après l'avoir
## quitté sans le fermer (l'appli était en arrière-plan). Aucune publicité au lancement à froid, ni
## au démarrage d'un niveau.
##
## Garde-fous (jamais de publicité involontaire ni répétitive) :
##  - absence d'au moins MIN_AWAY_MS (un simple coup d'œil à une notification n'en déclenche pas) ;
##  - au moins COOLDOWN_MS depuis la dernière publicité de retour ;
##  - jamais sans interaction préalable : le retour doit suivre une session réellement démarrée ;
##  - jamais quand le retour vient d'une publicité plein écran (récompensée ou de retour) ;
##  - jamais pendant une manipulation de grille, une victoire en cours de résolution ou une action sensible.
## Les durées sont mesurées par une horloge monotone, jamais par l'heure civile du téléphone.

const MIN_AWAY_MS := 5_000
const COOLDOWN_MS := 60_000
const NEVER := -1  ## valeur de `since_last_return_ad_millis` quand aucune pub de retour n'a encore été montrée


static func should_show(
	away_millis: int, since_last_return_ad_millis: int, came_back_from_ad: bool,
	session_started: bool, moment: AdMoment
) -> bool:
	return (
		session_started
		and not came_back_from_ad
		and away_millis >= MIN_AWAY_MS
		and (since_last_return_ad_millis == NEVER or since_last_return_ad_millis >= COOLDOWN_MS)
		and can_show_now(moment)
	)


static func can_show_now(moment: AdMoment) -> bool:
	return (
		not moment.is_first_render
		and not moment.is_grid_being_touched
		and not moment.is_resolving_win
		and not moment.is_sensitive_action_pending
	)
