class_name HomeScreen
extends Control
## Accueil : un carrousel de chapitres que l'on fait glisser. Toucher le chapitre en cours ouvre directement son
## niveau en cours ; un chapitre verrouillé ou terminé répond par un court message (un niveau gagné ne se rejoue
## jamais). En haut : réglages à gauche, solde d'indices au centre, menu des niveaux à droite. Sous le carrousel : le bouton
## des trophées, puis la bannière du défi du jour.

## Hauteur maximale d'une carte de chapitre (dp) : plus courte que la pleine hauteur d'avant.
const CARD_MAX_HEIGHT := 468.0
const CARD_MIN_HEIGHT := 330.0

var _pager: ChapterPager
var _pager_holder: VBoxContainer
var _top_row: Control
var _trophy_holder: Control
var _trophy_entry: TrophyEntry
var _banner_holder: Control
var _daily_banner: DailyBanner
var _chip: HintChip
var _cards: Array[ChapterCardView] = []


static func create() -> HomeScreen:
	return HomeScreen.new()


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

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_left", 10)
	top.add_theme_constant_override("margin_right", 10)
	top.add_theme_constant_override("margin_top", 4)
	top.add_theme_constant_override("margin_bottom", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	# Gauche : réglages + aide ; centre : indices ; droite : niveaux. Les deux côtés se partagent l'espace à égalité,
	# donc le solde d'indices reste centré.
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := RingButton.create("ic_settings", Strings.t("cd_settings"), Wg.BLUE, Wg.BLUE_DARK)
	settings.sound = Sound.MENU_CHANGE
	settings.activated.connect(App.open_settings)
	left.add_child(settings)
	var help := RingButton.create("ic_help", Strings.t("help_button_description"), Wg.ORANGE, Wg.ORANGE_DARK)
	help.sound = Sound.MENU_CHANGE
	help.activated.connect(App.open_help)
	left.add_child(help)
	row.add_child(left)
	var home := App.home_model()
	_chip = HintChip.create_with(home.hint_balance)
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_chip)
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var monument := RingButton.create("ic_levels", Strings.t("cd_monument"))
	monument.sound = Sound.MENU_CHANGE
	monument.activated.connect(App.open_monument)
	right.add_child(monument)
	row.add_child(right)
	_top_row = top
	column.add_child(top)

	# Carrousel : des cartes plus courtes qu'avant (hauteur plafonnée), centrées dans l'espace disponible.
	_pager_holder = VBoxContainer.new()
	_pager_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pager_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	_pager_holder.add_theme_constant_override("separation", 0)
	_pager_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_pager = ChapterPager.new()
	_pager.size_flags_horizontal = Control.SIZE_FILL
	_pager.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pager.on_offsets = _on_offsets
	_pager.page_changed.connect(_on_page_changed)
	_pager_holder.add_child(_pager)
	_pager_holder.resized.connect(_fit_pager)
	column.add_child(_pager_holder)

	# Trophées : bouton sous le carrousel (les anciens points de pagination ont disparu).
	var trophy_holder := MarginContainer.new()
	trophy_holder.add_theme_constant_override("margin_left", 18)
	trophy_holder.add_theme_constant_override("margin_right", 18)
	trophy_holder.add_theme_constant_override("margin_top", 6)
	trophy_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_trophy_entry = _make_trophy_entry()
	_trophy_entry.activated.connect(App.open_trophies)
	trophy_holder.add_child(_trophy_entry)
	_trophy_holder = trophy_holder
	column.add_child(trophy_holder)
	column.add_child(_gap(10.0))
	# Défi du jour : bannière sous le carrousel
	var banner_holder := MarginContainer.new()
	banner_holder.add_theme_constant_override("margin_left", 18)
	banner_holder.add_theme_constant_override("margin_right", 18)
	banner_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_daily_banner = DailyBanner.create(App.daily_model())
	_daily_banner.activated.connect(App.open_daily)
	banner_holder.add_child(_daily_banner)
	_banner_holder = banner_holder
	column.add_child(banner_holder)
	column.add_child(_gap(16.0))

	_build_pages(home, home.start_page)
	App.progress_changed.connect(_on_progress_changed)
	App.daily_changed.connect(_on_daily_changed)


## Plafonne la hauteur du carrousel : une carte reste une « bulle » compacte, centrée dans l'espace libre.
func _fit_pager() -> void:
	var holder_height := _pager_holder.size.y
	var wanted := clampf(holder_height - 16.0, CARD_MIN_HEIGHT, CARD_MAX_HEIGHT)
	if absf(_pager.custom_minimum_size.y - wanted) > 0.5:
		_pager.custom_minimum_size.y = wanted


## Pour la chorégraphie de transition : barre du haut, carrousel, trophées, défi du jour.
func transition_groups() -> Array:
	return [[_top_row, "top"], [_pager_holder, "center"], [_trophy_holder, "bottom"], [_banner_holder, "bottom"]]


func _on_daily_changed() -> void:
	if is_instance_valid(_daily_banner):
		_daily_banner.apply(App.daily_model())


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _build_pages(home: HomeModel, start_page: int) -> void:
	_cards.clear()
	var pages: Array[Control] = []
	for card in home.chapters:
		var view := ChapterCardView.create(card, App.language)
		view.activated.connect(func() -> void: App.open_chapter(card.index))
		view.claim_pressed.connect(func() -> void: App.claim_gift(card.index))
		_cards.append(view)
		# Chaque carte est enveloppée : le carrousel incline l'enveloppe, la carte garde sa pression « gelée ».
		var wrapper := Control.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
		var inset := MarginContainer.new()
		inset.mouse_filter = Control.MOUSE_FILTER_PASS
		UiKit.full_rect(inset)
		inset.add_theme_constant_override("margin_top", 10)
		inset.add_theme_constant_override("margin_bottom", 10)
		inset.add_theme_constant_override("margin_left", 2)
		inset.add_theme_constant_override("margin_right", 2)
		view.size_flags_horizontal = Control.SIZE_FILL
		view.size_flags_vertical = Control.SIZE_FILL
		inset.add_child(view)
		wrapper.add_child(inset)
		pages.append(wrapper)
	_pager.set_pages(pages, start_page)


func _on_offsets(page: int, offset: float) -> void:
	# Carrousel : la carte centrale est grande et droite, ses voisines reculent en s'inclinant légèrement.
	var wrapper := _pager.get_child(page) as Control
	var a := clampf(absf(offset), 0.0, 1.0)
	var s := 1.0 - 0.13 * a
	UiKit.tilt_from_bottom(wrapper, s, offset * -4.0, a * 22.0)
	if page < _cards.size():
		_cards[page].set_pager_offset(offset)


func _make_trophy_entry() -> TrophyEntry:
	return TrophyEntry.create(TrophyRules.unlocked_count(App.progress), TrophyCatalog.all().size(), TrophyRules.unseen_ids(App.progress).size())


func _on_page_changed(_page: int) -> void:
	Feedback.play(Sound.SWIPE)
	Feedback.perform(HapticEffect.SELECTION)


func _on_progress_changed() -> void:
	var home := App.home_model()
	if home == null:
		return
	_chip.set_count(home.hint_balance)
	_trophy_entry.apply(TrophyRules.unlocked_count(App.progress), TrophyCatalog.all().size(), TrophyRules.unseen_ids(App.progress).size())
	_build_pages(home, _pager.current_page())
	_daily_banner.apply(App.daily_model())
