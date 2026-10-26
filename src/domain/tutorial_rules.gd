class_name TutorialRules
extends RefCounted
## Tutoriels du jeu (fonctions pures, testées) :
##  - prise en main : au niveau 1 du chapitre 1, un gant montre les tracés un par un (aucun texte) ;
##  - cinématique de l'indice : la toute première fois que le joueur arrive au niveau 4 du chapitre 1, un gant l'invite à toucher
##    « Indice » ; un indice lui est offert, une seule fois (mémorisé dans `ProgressState.stats`, sans changer le schéma).

const HINT_INTRO_SEEN := "tutorial_hint_seen"
const HINT_INTRO_LEVEL := 4
const HINT_INTRO_GIFT := 1


## Vrai à la toute première ouverture du jeu : rien n'a encore été terminé, le niveau 1 du chapitre 1 reste à jouer. Le gant invite alors
## le joueur, depuis l'écran d'accueil, à toucher « Jouer » sur la bulle du chapitre 1 (puis le tutoriel continue sur le niveau 1).
static func home_intro_due(state: ProgressState, catalog: LevelCatalog) -> bool:
	if catalog == null or not state.completed.is_empty():
		return false
	for level in catalog.levels:
		if not level.is_daily() and level.chapter_index == 1 and level.number == 1:
			return not state.completed.has(level.id)
	return false


static func is_first_level(level: Level) -> bool:
	return level != null and not level.is_daily() and level.chapter_index == 1 and level.number == 1


static func is_hint_intro_level(level: Level) -> bool:
	return level != null and not level.is_daily() and level.chapter_index == 1 and level.number == HINT_INTRO_LEVEL


## Vrai quand la cinématique de l'indice doit se lancer pour ce niveau : jamais vue, niveau pas encore gagné.
static func hint_intro_due(state: ProgressState, level: Level) -> bool:
	return is_hint_intro_level(level) and not state.completed.has(level.id) and int(state.stats.get(HINT_INTRO_SEEN, 0)) == 0


## Marque la cinématique comme vue et offre l'indice (une seule fois : un second appel renvoie l'état reçu, inchangé).
static func begin_hint_intro(state: ProgressState) -> ProgressState:
	if int(state.stats.get(HINT_INTRO_SEEN, 0)) != 0:
		return state
	var next := state.copy()
	next.stats[HINT_INTRO_SEEN] = 1
	next.hint_balance += HINT_INTRO_GIFT
	return next
