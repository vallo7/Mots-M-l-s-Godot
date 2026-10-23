class_name ChapterCard
extends RefCounted
## Carte de chapitre du carrousel d'accueil. Toucher le chapitre courant ouvre son niveau en cours.

var index: int
var theme: Dictionary
var palette_key: String
var status: int
var completed_count: int
var total: int
var stars_earned: int
var stars_max: int
## Niveau en cours (renseigné seulement si `status` est ChapterStatus.CURRENT), sinon null.
var current_level: Level
var has_snapshot: bool
var trophy_claimable: bool
var trophy_claimed: bool


## Résolution du chapitre en pourcentage (0..100) : étoiles gagnées sur étoiles possibles, arrondi à l'entier.
func percent() -> int:
	if stars_max <= 0:
		return 0
	return clampi(int(round(100.0 * float(stars_earned) / float(stars_max))), 0, 100)


## Progression continue 0..1 de la barre du chapitre.
func fraction() -> float:
	return 0.0 if total == 0 else float(completed_count) / float(total)
