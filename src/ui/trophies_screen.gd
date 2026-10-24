class_name TrophiesScreen
extends Control
## Menu des trophées : barre du haut (retour, titre), résumé « n / 20 », puis les trophées en icônes sur trois colonnes
## (du plus simple au plus rare). Un appui sur une icône ouvre sa fiche. Les trophées débloqués depuis la dernière visite
## portent l'étiquette « Nouveau » ; ils sont ensuite marqués comme vus.

const COLUMNS := 3
const GAP := 10.0
const SIDE_MARGIN := 16

var _top_bar_node: Control
var _scroll: ScrollContainer
var _summary: Control
var _tiles: Array[TrophyTile] = []


static func create() -> TrophiesScreen:
	return TrophiesScreen.new()


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Wg.BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(background)
	add_child(background)
	var watermark := WatermarkBackground.new()
	UiKit.full_rect(watermark)
	add_child(watermark)

	var state := App.progress
	var unseen := TrophyRules.unseen_ids(state)
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

	var top := ScreenTopBar.create(Strings.t("trophies_title"))
	top.back_pressed.connect(App.on_back)
	var top_margin := MarginContainer.new()  # le bouton retour ne touche plus la zone sûre
	top_margin.add_theme_constant_override("margin_left", UiKit.edge(0))
	top_margin.add_theme_constant_override("margin_right", UiKit.edge(0))
	top_margin.add_theme_constant_override("margin_top", UiKit.edge(0))
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(top)
	_top_bar_node = top_margin
	column.add_child(top_margin)

	var total := TrophyCatalog.all().size()
	var unlocked := TrophyRules.unlocked_count(state)
	_summary = _summary_row(unlocked, total)
	column.add_child(_summary)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", SIDE_MARGIN)
	pad.add_theme_constant_override("margin_right", SIDE_MARGIN)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", int(Wg.SP_XL))
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	pad.add_child(grid)
	for trophy in TrophyCatalog.all():
		var tile := TrophyTile.create(
			trophy, TrophyRules.is_unlocked(state, trophy.id), TrophyRules.progress_of(trophy, App.catalog, state), unseen.has(trophy.id)
		)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var trophy_id := trophy.id
		tile.activated.connect(func() -> void: _open_detail(trophy_id))
		grid.add_child(tile)
		_tiles.append(tile)
	# Tout ce qui est débloqué est désormais « vu » (la pastille de l'accueil s'éteint).
	if not unseen.is_empty():
		App.mark_trophies_seen()


## Résumé : trophée doré, « n / 20 débloqués » et barre d'avancement.
func _summary_row(unlocked: int, total: int) -> Control:
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_left", SIDE_MARGIN)
	holder.add_theme_constant_override("margin_right", SIDE_MARGIN)
	holder.add_theme_constant_override("margin_top", 2)
	holder.add_theme_constant_override("margin_bottom", 8)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	row.add_child(UiKit.icon("ic_trophy", 44.0))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Wg.label(Strings.t("trophies_summary", [unlocked, total]), 16.0, Wg.Weight.BLACK, Wg.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(label)
	var bar := ChunkyProgressBar.create(float(unlocked) / maxi(total, 1), Wg.YELLOW, Wg.YELLOW_DARK, 14.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(bar)
	row.add_child(texts)
	holder.set("accessibility_name", Strings.t("trophies_summary", [unlocked, total]))
	return holder


func _open_detail(trophy_id: String) -> void:
	var trophy := TrophyCatalog.by_id(trophy_id)
	if trophy != null:
		TrophyDetailPopup.open(self, trophy, App.progress, App.catalog)


## Pour la chorégraphie de transition : barre du haut, résumé, puis la grille.
func transition_groups() -> Array:
	return [[_top_bar_node, "top"], [_summary, "top"], [_scroll, "center"]]


## La page est en place : les cases apparaissent en cascade (ligne par ligne).
func on_entered() -> void:
	for i in _tiles.size():
		UiFx.pop_in(_tiles[i], 0.03 * float(i / COLUMNS) + 0.015 * float(i % COLUMNS), 14.0)
