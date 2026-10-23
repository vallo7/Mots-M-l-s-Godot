class_name StartupSequence
extends RefCounted
## Séquence de démarrage à froid. Chaque étape est réellement exécutée : lecture des niveaux, validation
## des grilles (sur un thread de travail : l'écran de chargement reste animé), lecture de la progression
## et des réglages, préchargement des sons. La durée minimale (2,8 s : assez pour voir une boucle de la démonstration du gant) est appliquée une seule fois, après
## la dernière étape, jamais lors des navigations suivantes.

enum Step { READING_LEVELS, CHECKING_GRIDS, LOADING_PROGRESS, LOADING_AUDIO, READY }

const MIN_DURATION_MS := 2_800

signal progressed(progress: float, step: int)

var _repository: LevelRepository
var _load_profile: Callable  ## () -> void
var _preload_audio: Callable  ## () -> void (peut contenir des await)
var _tree: SceneTree
var _minimum_ms: int
## Résultat : catalogue, ou null en cas d'échec (voir `error` et `issues`).
var catalog: LevelCatalog
var error: String = ""
var issues: Array[ValidationIssue] = []


func _init(
	tree: SceneTree, repository: LevelRepository, load_profile: Callable, preload_audio: Callable,
	minimum_ms: int = MIN_DURATION_MS
) -> void:
	_tree = tree
	_repository = repository
	_load_profile = load_profile
	_preload_audio = preload_audio
	_minimum_ms = minimum_ms


## À appeler avec `await`. Renvoie true si le démarrage a réussi.
func run() -> bool:
	var started_at := Time.get_ticks_msec()
	progressed.emit(0.0, Step.READING_LEVELS)
	await _tree.process_frame
	catalog = _repository.load_catalog()
	if catalog == null:
		error = "Lecture des niveaux impossible"
		return false

	progressed.emit(0.25, Step.CHECKING_GRIDS)
	var holder: Array = [[] as Array[ValidationIssue]]
	var task_id := WorkerThreadPool.add_task(func() -> void: holder[0] = LevelValidator.validate_catalog(catalog))
	while not WorkerThreadPool.is_task_completed(task_id):
		await _tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task_id)
	issues = holder[0]
	if not issues.is_empty():
		error = "%d problème(s) dans les niveaux" % issues.size()
		catalog = null
		return false

	progressed.emit(0.5, Step.LOADING_PROGRESS)
	await _tree.process_frame
	_load_profile.call()

	progressed.emit(0.75, Step.LOADING_AUDIO)
	await _tree.process_frame
	# Un son qui ne charge pas ne doit jamais empêcher de jouer.
	await _preload_audio.call()

	progressed.emit(1.0, Step.READY)
	var remaining := _minimum_ms - (Time.get_ticks_msec() - started_at)
	if remaining > 0:
		await _tree.create_timer(remaining / 1000.0).timeout
	return true
