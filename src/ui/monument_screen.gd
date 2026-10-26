class_name MonumentScreen
extends Control
## Monument des niveaux, dans le style de la maquette « liste de niveaux » : barre du haut (retour, progression
## du chapitre en cours, indices), bandeau illustré par chapitre (titre écrit en bas de l'illustration), puis dix pilules. Niveau terminé : étoiles + coche,
## pas de relance. Niveau disponible : bouton lecture. Niveau verrouillé : cadenas. Le niveau 10 (défi final) est doré.


## Durée du défilement jusqu'au niveau en cours : proportionnelle à la distance, bornée.
const UNROLL_MIN_SECONDS := 0.7
const UNROLL_MAX_SECONDS := 1.5
const UNROLL_PIXELS_PER_SECOND := 1500.0

var _scroll: SmoothScroll
var _list: VBoxContainer
var _top_bar_node: Control
var _current_holder: Control
var _unroll: Tween


static func create() -> MonumentScreen:
	return MonumentScreen.new()


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Wg.BACKGROUND
	UiKit.full_rect(background)
	add_child(background)
	var chapters := MonumentBuilder.build(App.catalog, App.progress)
	# Chapitre en cours : le premier qui a encore un niveau disponible (sinon le dernier, tout est terminé).
	var current_chapter := chapters[chapters.size() - 1].index if not chapters.is_empty() else 1
	for chapter in chapters:
		var has_available := false
		for level in chapter.levels:
			if level.status == LevelStatus.AVAILABLE:
				has_available = true
		if has_available:
			current_chapter = chapter.index
			break
	# La barre du haut montre la progression du chapitre en cours (et non celle de tous les chapitres).
	var fraction := 0.0
	for chapter in chapters:
		if chapter.index == current_chapter and not chapter.levels.is_empty():
			fraction = float(chapter.completed_count) / chapter.levels.size()

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
	_top_bar_node = _top_bar(current_chapter, fraction)
	column.add_child(_top_bar_node)

	var scroll := SmoothScroll.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	_list = list
	var found_current := false
	for chapter in chapters:
		list.add_child(_chapter_header(chapter))
		for level in chapter.levels:
			var holder := MarginContainer.new()
			holder.add_theme_constant_override("margin_left", 16)
			holder.add_theme_constant_override("margin_right", 16)
			holder.mouse_filter = Control.MOUSE_FILTER_PASS
			var pill := LevelPill.create(chapter, level, App.language)
			var level_id := level.level_id
			pill.activated.connect(func() -> void: App.open_level(level_id))
			holder.add_child(pill)
			list.add_child(holder)
			# Niveau en cours : le premier niveau disponible (sinon on se rend tout en bas, tout est terminé).
			if not found_current and level.status == LevelStatus.AVAILABLE:
				_current_holder = holder
				found_current = true
		list.add_child(_gap(10.0))
	list.add_child(_gap(Wg.SP_XL))
	scroll.scroll_started.connect(_stop_unroll)
	# Reconstruction en place (langue, thème) ou animations réduites : on se place directement, sans dérouler.
	if Wg.suppress_intro or Wg.reduce_motion:
		_jump_to_current.call_deferred()


## Pour la chorégraphie de transition : barre du haut, puis la liste.
func transition_groups() -> Array:
	return [[_top_bar_node, "top"], [_scroll, "center"]]


## La page est en place : le menu se déroule depuis le haut jusqu'au niveau en cours.
func on_entered() -> void:
	if Wg.reduce_motion:
		_jump_to_current()
		return
	await get_tree().process_frame
	var target := _target_scroll()
	if target <= 8:
		_pulse_current()
		return
	_stop_unroll()
	_scroll.scroll_position = 0.0
	var seconds := clampf(float(target) / UNROLL_PIXELS_PER_SECOND, UNROLL_MIN_SECONDS, UNROLL_MAX_SECONDS)
	_unroll = create_tween()
	_unroll.tween_property(_scroll, "scroll_position", float(target), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_unroll.tween_callback(_pulse_current)


## Défilement qui place le niveau en cours à environ un tiers de la hauteur visible (jamais au-delà de la fin).
func _target_scroll() -> int:
	if _scroll == null or _list == null:
		return 0
	var anchor_y := _list.size.y  # tout en bas si aucun niveau disponible
	var height := 0.0
	if _current_holder != null:
		anchor_y = _current_holder.position.y
		height = _current_holder.size.y
	var wanted := anchor_y - (_scroll.size.y - height) * 0.33
	var max_scroll := maxf(_list.size.y - _scroll.size.y, 0.0)
	return int(clampf(wanted, 0.0, max_scroll))


func _jump_to_current() -> void:
	if _scroll == null:
		return
	await get_tree().process_frame
	_scroll.scroll_position = float(_target_scroll())


func _stop_unroll() -> void:
	if _unroll != null and _unroll.is_valid():
		_unroll.kill()
	_unroll = null


## Petit rebond du niveau en cours quand le défilement s'arrête : on voit où l'on en est.
func _pulse_current() -> void:
	if _current_holder == null or not is_instance_valid(_current_holder):
		return
	var holder := _current_holder
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var s := 1.0 + 0.05 * Motion.bump(t) + 0.025 * sin(t * TAU * 2.0) * (1.0 - t)
		UiKit.transform_visual(holder, Vector2.ZERO, Vector2(s, s)), 0.0, 1.0, 0.55)
	tween.tween_callback(func() -> void: UiKit.transform_visual(holder, Vector2.ZERO, Vector2.ONE))


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _top_bar(current_chapter: int, fraction: float) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiKit.edge(10))
	margin.add_theme_constant_override("margin_right", UiKit.edge(10))
	margin.add_theme_constant_override("margin_top", UiKit.edge(6))
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var back := RingButton.create("ic_back", Strings.t("cd_back"))
	back.sound = Sound.MENU_CHANGE
	back.activated.connect(App.on_back)
	row.add_child(back)

	var middle := Control.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.custom_minimum_size = Vector2(0.0, 32.0)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var current := App.catalog.chapter_by_index(current_chapter)
	var chapter_palette := Wg.chapter_theme(current.palette_key if current != null else "meadow")
	var bar := ChunkyProgressBar.create(fraction, chapter_palette["color"], chapter_palette["dark"], 18.0)
	bar.anchor_right = 1.0
	bar.anchor_top = 0.5
	bar.anchor_bottom = 0.5
	bar.offset_left = 16.0
	bar.offset_top = -9.0
	bar.offset_bottom = 9.0
	middle.add_child(bar)
	var badge := _ChapterBadge.new()
	badge.face = chapter_palette["color"]
	badge.lip = chapter_palette["dark"]
	badge.custom_minimum_size = Vector2(32.0, 32.0)
	badge.size = Vector2(32.0, 32.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UiKit.centered(Wg.label(str(current_chapter), 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE)))
	middle.add_child(badge)
	row.add_child(middle)
	row.add_child(HintChip.create_with(App.progress.hint_balance))
	return margin


class _ChapterBadge extends Control:
	var face := Wg.GREEN
	var lip := Wg.GREEN_DARK

	func _draw() -> void:
		Wg.rrect(self, Rect2(Vector2.ZERO, size), lip, 16.0)
		Wg.rrect(self, Rect2(Vector2.ZERO, size - Vector2(0.0, 2.0)), face, 16.0)


func _chapter_header(chapter: MonumentChapter) -> Control:
	var palette := Wg.chapter_theme(chapter.palette_key)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := Control.new()
	band.custom_minimum_size = Vector2(0.0, 150.0)
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky := ColorRect.new()
	sky.color = palette["sky"]
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(sky)
	band.add_child(sky)
	var art := TextureRect.new()
	art.texture = Icons.get_icon(palette["illustration"])
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(art)
	band.add_child(art)
	# Plus de bannière sur l'illustration : le titre du chapitre est écrit en bas de l'illustration, en gras blanc cerné
	# de la couleur du chapitre (lisible sur n'importe quel décor, sans voile ni fondu).
	var title_text := Strings.t("monument_chapter", [chapter.index, Language.pick(chapter.theme, App.language)])
	var title := Wg.label(title_text, 24.0, Wg.Weight.BLACK, Wg.WHITE)
	title.add_theme_color_override("font_outline_color", palette["dark"])
	title.add_theme_constant_override("outline_size", 9)
	title.add_theme_color_override("font_shadow_color", Color(Wg.SHADOW, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.04
	title.anchor_right = 0.96
	title.anchor_top = 1.0
	title.anchor_bottom = 1.0
	title.offset_top = -46.0
	title.offset_bottom = -8.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fit_font(title, 330.0, int(round(24.0 * Wg.text_scale)), 13)
	band.add_child(title)
	column.add_child(band)

	var progress := MarginContainer.new()
	progress.add_theme_constant_override("margin_left", 16)
	progress.add_theme_constant_override("margin_right", 16)
	progress.add_theme_constant_override("margin_top", 12)
	progress.add_theme_constant_override("margin_bottom", 12)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.set("accessibility_name", Strings.t("home_gift_description", [chapter.completed_count, chapter.levels.size()]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ChunkyProgressBar.create(float(chapter.completed_count) / maxi(chapter.levels.size(), 1), palette["color"], palette["dark"], 18.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(GiftBadge.create(chapter.gift_claimable, 44.0))
	progress.add_child(row)
	column.add_child(progress)
	if chapter.gift_claimable:
		var holder := MarginContainer.new()
		holder.add_theme_constant_override("margin_left", 16)
		holder.add_theme_constant_override("margin_right", 16)
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		var claim := WgButton.create(Strings.t("home_gift_claim"), WgButton.Kind.PRIMARY, "", true)
		claim.sound = Sound.GIFT
		claim.haptic = HapticEffect.SUCCESS
		var chapter_index := chapter.index
		claim.activated.connect(func() -> void: App.claim_gift(chapter_index))
		holder.add_child(claim)
		column.add_child(holder)
	return column
