class_name ProgressState
extends RefCounted
## Progression persistante (sérialisée par la couche data, avec migration de schéma).
## Tout changement passe par ProgressRules : fonctions pures qui renvoient un nouvel état.

## 2 : défi quotidien ajouté ; les parties en cours des anciennes grilles sont abandonnées (niveaux renouvelés).
## 3 : trophées (compteurs, trophées débloqués et vus). Champs additifs : la migration ne change aucune donnée.
const CURRENT_SCHEMA := 3

var schema_version: int = CURRENT_SCHEMA
var initial_hints_granted := false
var hint_balance: int = 0
var completed: Dictionary = {}  ## id niveau (String) -> LevelResult
## Indices des chapitres dont le cadeau a été réclamé.
var claimed_gift_chapters: Array[int] = []
## Identifiants des dernières récompenses publicitaires déjà accordées (anti-doublon).
var granted_reward_ids: Array[String] = []
var last_praise: int = Praise.NONE
## Niveaux consécutifs terminés avec 3 étoiles.
var perfect_streak: int = 0
## Parties en cours, clé « idNiveau:langue » (String) -> GameSnapshot. Supprimées à la victoire.
var in_progress: Dictionary = {}
## Défi quotidien : jour (int) -> LevelResult, série de jours consécutifs, meilleure série, dernier jour réussi (-1 = aucun),
## paliers de série déjà récompensés dans la série en cours.
var daily_results: Dictionary = {}
var daily_streak: int = 0
var daily_best_streak: int = 0
var daily_last_day: int = -1
var daily_claimed_milestones: Array[int] = []
## Compteurs mémorisés pour les trophées (clé -> entier ; voir TrophyRules), trophées débloqués (id -> secondes Unix du
## déblocage) et identifiants déjà vus dans le menu des trophées.
var stats: Dictionary = {}
var trophies: Dictionary = {}
var trophies_seen: Array[String] = []


func copy() -> ProgressState:
	var c := ProgressState.new()
	c.schema_version = schema_version
	c.initial_hints_granted = initial_hints_granted
	c.hint_balance = hint_balance
	c.completed = completed.duplicate()
	c.claimed_gift_chapters = claimed_gift_chapters.duplicate()
	c.granted_reward_ids = granted_reward_ids.duplicate()
	c.last_praise = last_praise
	c.perfect_streak = perfect_streak
	c.in_progress = in_progress.duplicate()
	c.daily_results = daily_results.duplicate()
	c.daily_streak = daily_streak
	c.daily_best_streak = daily_best_streak
	c.daily_last_day = daily_last_day
	c.daily_claimed_milestones = daily_claimed_milestones.duplicate()
	c.stats = stats.duplicate()
	c.trophies = trophies.duplicate()
	c.trophies_seen = trophies_seen.duplicate()
	return c
