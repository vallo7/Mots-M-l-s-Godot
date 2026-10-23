class_name VictoryResult
extends RefCounted

var level_id: String
var chapter_index: int
var stars: int
var elapsed_millis: int
var praise: int
var chapter_completed: bool
var gift_claimable: bool
var next_level_id: String  ## "" = dernier niveau
## Niveaux terminés du chapitre avant / après cette victoire : alimente la barre de progression de fin de niveau.
var chapter_completed_before: int
var chapter_completed_after: int
var chapter_total: int
## Défi du jour : détail des récompenses et de la série (null pour un niveau ordinaire).
var is_daily := false
var daily_day := 0
var daily: DailyCompletion
