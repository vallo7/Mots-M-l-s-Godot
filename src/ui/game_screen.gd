class_name GameScreen
extends Control
## Écran de jeu. De haut en bas : barre (retour, niveau, redémarrer), badge de difficulté + chronomètre agrandi,
## mots à trouver, grille (point focal, la plus grande possible), bouton Indice à droite sous la grille, zone réservée
## à la bannière. Le redémarrage est immédiat : la grille mélange ses lettres, sans fenêtre de confirmation. Un indice
## demandé sans solde lance directement la publicité, sans fenêtre non plus.

## Couleurs des mots trouvés : vives sur la pastille de la liste ; la capsule dans la grille en est une version adoucie
## (moins saturée, translucide : voir Wg.trace_tint) pour que les lettres restent lisibles.
const WORD_COLORS: Array[Color] = [Wg.PINK, Wg.BLUE, Wg.GREEN, Wg.ORANGE, Wg.PURPLE, Wg.TEAL, Wg.RED, Wg.YELLOW_DARK]
const BANNER_HEIGHT := 50.0
## Écart entre le bouton Indice (ombre comprise) et la bannière publicitaire : le bouton ne la touche jamais.
const HINT_BANNER_GAP := 22

## Nombre d'écrans de jeu vivants (2 un instant quand l'écran est reconstruit en place).
static var _alive := 0
var _banner_allowed := false
const GRID_SIDE_MARGIN := 6
## Micro-délai avant la cinématique de l'indice (laisse la page s'installer).
const HINT_INTRO_DELAY := 0.7

var controller: GameController

var _grid: LetterGridView
var _timer_label: Label
var _chips: Array[WordChip] = []
var _hint_button: HintButton
var _popup: PopupHost
var _popup_kind: int = GameController.Dialog.NONE
var _move_tutorial: MoveTutorial
var _hint_intro: HintIntro
var _tutorials_started := false
var _last_found: Array[int] = [-1]  # valeur sentinelle : la première synchronisation initialise le moteur d'effets
var _last_selection: Array[Vector2i] = []
var _last_hints: Array[Vector2i] = []
var _words: Array[TargetWord]
## Éléments qui entrent et sortent un à un lors des changements de page (voir transition_groups).
var _g_top: Control
var _g_badges: Control
var _g_words: Control
var _g_grid: Control
var _g_hint: Control


static func create(p_controller: GameController) -> GameScreen:
	var screen := GameScreen.new()
	screen.controller = p_controller
	return screen


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var level := controller.level
	var language := controller.language
	var style := Wg.style_palette(level.visual_style)
	var variant := level.variant(language)
	_words = variant.words

	var background := ColorRect.new()
	background.color = Wg.BACKGROUND
	UiKit.full_rect(background)
	add_child(background)

	var insets := App.safe_area_insets
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	margin.add_theme_constant_override("margin_left", int(insets.x))
	margin.add_theme_constant_override("margin_top", int(insets.y))
	margin.add_theme_constant_override("margin_right", int(insets.z))
	margin.add_theme_constant_override("margin_bottom", int(insets.w))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	_g_top = _build_top_bar(level, language)
	column.add_child(_g_top)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", int(Wg.SP_MD))
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(DifficultyBadge.create_for(DifficultyBand.of(level.number)))
	badge_row.add_child(_build_timer_pill())
	column.add_child(badge_row)
	_g_badges = badge_row
	column.add_child(_gap(Wg.SP_SM))

	_g_words = _build_words_panel()
	column.add_child(_g_words)

	var grid_holder := MarginContainer.new()
	grid_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Marges minimales : la grille prend le plus grand carré possible, centré, sans toucher les bords de l'écran.
	grid_holder.add_theme_constant_override("margin_left", GRID_SIDE_MARGIN)
	grid_holder.add_theme_constant_override("margin_right", GRID_SIDE_MARGIN)
	grid_holder.add_theme_constant_override("margin_top", 2)
	grid_holder.add_theme_constant_override("margin_bottom", 2)
	grid_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = LetterGridView.new()
	_grid.size_flags_horizontal = Control.SIZE_FILL
	_grid.size_flags_vertical = Control.SIZE_FILL
	_grid.set("accessibility_name", Strings.t("game_grid_description", [level.grid_size]))
	grid_holder.add_child(_grid)
	column.add_child(grid_holder)
	_g_grid = grid_holder

	var hint_row := HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_END
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_right", int(Wg.SP_MD))
	hint_margin.add_theme_constant_override("margin_top", 4)
	hint_margin.add_theme_constant_override("margin_bottom", HINT_BANNER_GAP)
	hint_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_button = HintButton.create()
	_hint_button.activated.connect(controller.on_hint_requested)
	hint_margin.add_child(_hint_button)
	hint_row.add_child(hint_margin)
	column.add_child(hint_row)
	_g_hint = hint_row

	var banner := ColorRect.new()  # zone réservée à la bannière : la grille ne bouge jamais
	banner.color = Wg.BACKGROUND
	banner.custom_minimum_size = Vector2(0.0, maxf(BANNER_HEIGHT, App.ads.banner_height()))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(banner)

	_grid.setup(variant.grid, style["accent"], controller.hint_cells)
	_grid.selection_started.connect(controller.on_selection_start)
	_grid.selection_changed.connect(controller.on_selection_change)
	_grid.selection_ended.connect(controller.on_selection_end)

	controller.changed.connect(_refresh)
	controller.found.connect(func(_i: int) -> void: pass)
	controller.wrong.connect(_grid.play_wrong)
	controller.restarted.connect(_on_restarted)
	controller.ad_launching.connect(_hint_button.play_ad_launch)
	controller.on_resume()
	_alive += 1
	App.progress_changed.connect(_sync_banner)
	# La bannière n'apparaît qu'une fois la page en place (`on_entered`) et disparaît dès qu'on la quitte (`on_leaving`) ;
	# une reconstruction en place (langue, thème) la garde telle quelle.
	if Wg.suppress_intro:
		_banner_allowed = true
		_sync_banner()
	_refresh()
	if Wg.suppress_intro:
		_start_tutorials()


## Pour la chorégraphie de transition : barre du haut, pastilles (difficulté, chrono), mots, grille, bouton Indice.
func transition_groups() -> Array:
	return [[_g_top, "top"], [_g_badges, "top"], [_g_words, "center"], [_g_grid, "center"], [_g_hint, "bottom"]]


## Redémarrage : la grille tourne d'un quart de tour (à gauche ou à droite) : mêmes mots, autres directions.
func _on_restarted(turns: int) -> void:
	var variant := controller.variant()
	_words = variant.words
	_grid.play_restart(variant.grid, turns)


## La page est en place (fin de transition) : la bannière peut s'afficher et les tutoriels démarrent.
func on_entered() -> void:
	_banner_allowed = true
	_sync_banner()
	_start_tutorials()


## Niveau 1 du chapitre 1 : le gant montre les tracés. Niveau 4 : la cinématique de l'indice (une seule fois, un indice offert).
func _start_tutorials() -> void:
	if _tutorials_started or _grid == null:
		return
	_tutorials_started = true
	if controller.wants_move_tutorial():
		_move_tutorial = MoveTutorial.attach(_grid, controller, _words)
	elif TutorialRules.is_hint_intro_level(controller.level):
		await get_tree().create_timer(HINT_INTRO_DELAY).timeout
		if not is_inside_tree() or not is_instance_valid(controller) or controller.solved:
			return
		if controller.begin_hint_intro():  # offre l'indice (une seule fois) puis affiche la cinématique
			_hint_intro = HintIntro.open(self, _hint_button)
			controller.hint_revealed.connect(func(_cell: Vector2i) -> void:
				if is_instance_valid(_hint_intro):
					_hint_intro.close())


## La transition de sortie démarre : la bannière disparaît tout de suite.
func on_leaving() -> void:
	_banner_allowed = false
	App.ads.set_banner_visible(false)


func _sync_banner() -> void:
	App.ads.set_banner_visible(_banner_allowed and App.ads_enabled)


func _exit_tree() -> void:
	# Un simple déplacement dans l'arbre (transition en iris) ne doit ni suspendre la partie ni retirer la bannière.
	if not is_queued_for_deletion():
		return
	_alive = maxi(_alive - 1, 0)
	if _alive > 0:
		return  # un écran de jeu reconstruit en place a déjà pris le relais : ni pause ni bannière retirée
	App.ads.set_banner_visible(false)
	if is_instance_valid(controller):
		controller.on_pause()


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _build_top_bar(level: Level, language: int) -> Control:
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_left", UiKit.edge(Wg.SP_SM))
	bar.add_theme_constant_override("margin_right", UiKit.edge(Wg.SP_SM))
	bar.add_theme_constant_override("margin_top", UiKit.edge(Wg.SP_XS))
	bar.add_theme_constant_override("margin_bottom", int(Wg.SP_XS))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	var back := RingButton.create("ic_back", Strings.t("cd_back"))
	back.sound = Sound.MENU_CHANGE
	back.activated.connect(controller.on_back_requested)
	row.add_child(back)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 0)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 6)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if level.is_daily():
		title_row.add_child(UiKit.icon("ic_calendar_color", 24.0))
	elif level.is_final_challenge():
		title_row.add_child(UiKit.icon("ic_crown", 22.0))
	title_row.add_child(Wg.label(Strings.t("daily_title") if level.is_daily() else Strings.t("home_chapter_level", [level.chapter_index, level.number]), 18.0, Wg.Weight.EXTRABOLD, Wg.INK))
	middle.add_child(title_row)
	var theme_label := Wg.label(Language.pick(level.theme, language), 14.0, Wg.Weight.BOLD, Wg.INK_MUTED)
	theme_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	middle.add_child(theme_label)
	row.add_child(middle)

	var restart := RingButton.create("ic_restart", Strings.t("cd_restart"), Wg.ORANGE, Wg.ORANGE_DARK)
	restart.sound = Sound.CLICK
	restart.activated.connect(controller.on_restart_requested)
	row.add_child(restart)
	return bar


## Chronomètre agrandi : horloge dorée + chiffres dans une grosse pastille.
func _build_timer_pill() -> Control:
	var pill := Pill.create(Wg.TRACK, Vector4(8, 3, 18, 3), Color(0, 0, 0, 0), 0.0, 8.0)
	pill.row.add_child(UiKit.icon("ic_clock", 32.0))
	_timer_label = Wg.label("0:00", 30.0, Wg.Weight.BLACK, Wg.INK)
	pill.row.add_child(_timer_label)
	return pill


## Mots à trouver, au-dessus de la grille : pastilles qui s'enchaînent à la ligne.
func _build_words_panel() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(Wg.SP_MD))
	margin.add_theme_constant_override("margin_right", int(Wg.SP_MD))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.set("accessibility_name", Strings.t("game_words_label"))
	var compact := _words.size() > 10
	for i in _words.size():
		var chip := WordChip.create(_words[i].display, WORD_COLORS[i % WORD_COLORS.size()], compact)
		_chips.append(chip)
		flow.add_child(chip)
	margin.add_child(flow)
	return margin


func _refresh() -> void:
	var c := controller
	_timer_label.text = TimeFormat.mmss(c.elapsed_millis)
	_timer_label.set("accessibility_name", Strings.t("game_timer_description", [_timer_label.text]))
	for i in _chips.size():
		_chips[i].set_found(c.found_word_indices.has(i), _last_found_known)
	_last_found_known = true
	_hint_button.set_balance(c.hint_balance, c.ready_to_play and not c.solved)
	_grid.input_enabled = c.ready_to_play and not c.solved and c.dialog == GameController.Dialog.NONE

	if c.found_word_indices != _last_found:
		_last_found = c.found_word_indices.duplicate()
		var highlights: Array[FoundHighlight] = []
		var sorted := _last_found.duplicate()
		sorted.sort()
		for index in sorted:
			highlights.append(FoundHighlight.new(_words[index].cells, Wg.trace_tint(WORD_COLORS[index % WORD_COLORS.size()])))
		_grid.update_found(highlights)
	if c.selection != _last_selection:
		_last_selection = c.selection.duplicate()
		_grid.update_selection(c.selection)
	if c.hint_cells != _last_hints:
		_last_hints = c.hint_cells.duplicate()
		_grid.update_hints(c.hint_cells)
	_sync_popup()


var _last_found_known := false


func _sync_popup() -> void:
	if controller.dialog == _popup_kind:
		return
	if _popup != null:
		_popup.close()
		_popup = null
	_popup_kind = controller.dialog
	match controller.dialog:
		GameController.Dialog.CONFIRM_QUIT:
			_popup = ConfirmPopup.open(
				self, Strings.t("dialog_quit_title"), Strings.t("dialog_quit_body"), Strings.t("dialog_quit_confirm"),
				Strings.t("dialog_stay"), controller.confirm_quit, controller.dismiss_dialog
			)
