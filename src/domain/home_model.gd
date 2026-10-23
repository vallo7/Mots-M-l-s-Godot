class_name HomeModel
extends RefCounted
## Ce que l'accueil affiche : chapitres (carrousel), niveau en cours, progression vers le trophée, solde d'indices.

var current_level: Level
var current_chapter: Chapter
## Chapitre dont la progression/le cadeau est mis en avant.
var gift_chapter: Chapter
var gift_chapter_completed: int
var gift_chapter_total: int
var gift_claimable: bool
var hint_balance: int
var all_completed: bool
var has_snapshot: bool
var chapters: Array[ChapterCard] = []
## Page à afficher à l'ouverture : le chapitre courant (ou le dernier si tout est terminé).
var start_page: int = 0
