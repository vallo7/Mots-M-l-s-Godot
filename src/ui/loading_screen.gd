class_name LoadingScreen
extends Control
## Chargement réel : la barre reflète les étapes exécutées (progression déterministe) et s'étale sur la durée minimale
## (jamais plus vite que la réalité). À la place d'un logo, le gant joue en boucle une démonstration d'une mécanique du
## jeu (3 scénarios, un au hasard à chaque ouverture). La barre est posée tout en bas de l'écran, avec l'étape en cours
## en petit dessous, puis la mention discrète du studio. Aucun texte de conseil.

## La barre vise 100 % au bout de ce temps (légèrement sous la durée minimale du démarrage, pour finir avec elle).
const BAR_SECONDS := 2.6
## Espace entre la mention du studio et le bas de l'écran (en plus de la zone sûre).
const BOTTOM_PADDING := 20.0

var scenario := -1

var _bar: ChunkyProgressBar
var _step_label: Label
var _progress := 0.0
var _shown := 0.0
var _elapsed := 0.0


## `p_scenario` : -1 = au hasard (les tests fixent la valeur).
static func create(p_scenario: int = -1) -> LoadingScreen:
	var screen := LoadingScreen.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	screen.scenario = p_scenario if p_scenario >= 0 else rng.randi_range(0, LoadingDemo.SCENARIO_COUNT - 1)
	return screen


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Wg.BACKGROUND
	UiKit.full_rect(background)
	add_child(background)

	var insets := App.safe_area_insets
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	margin.add_theme_constant_override("margin_left", int(insets.x + Wg.SP_XL))
	margin.add_theme_constant_override("margin_top", int(insets.y + Wg.SP_LG))
	margin.add_theme_constant_override("margin_right", int(insets.z + Wg.SP_XL))
	margin.add_theme_constant_override("margin_bottom", int(insets.w + BOTTOM_PADDING))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)

	# Démonstration du gant : centrée dans toute la place disponible au-dessus de la barre.
	var demo_holder := CenterContainer.new()
	demo_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	demo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_holder.add_child(LoadingDemo.create(scenario, App.language))
	column.add_child(demo_holder)

	# Barre et étape, tout en bas.
	var bar_holder := CenterContainer.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = ChunkyProgressBar.create(0.0, Wg.PURPLE, Wg.PURPLE_DARK, 16.0)
	_bar.custom_minimum_size = Vector2(0.62 * (size.x - 2.0 * Wg.SP_XL if size.x > 0.0 else 296.0), 16.0)
	_bar.set("accessibility_name", Strings.t("loading_progress_description"))
	bar_holder.add_child(_bar)
	column.add_child(bar_holder)
	column.add_child(_gap(Wg.SP_SM))
	_step_label = Wg.label(Strings.t(App.loading_label_key), 13.0, Wg.Weight.BOLD, Wg.INK_MUTED)
	column.add_child(_step_label)
	column.add_child(_gap(Wg.SP_LG))
	# Mention discrète du studio.
	var studio := Wg.label(Strings.t("loading_studio"), 11.0, Wg.Weight.BOLD, Color(Wg.INK_MUTED, 0.75))
	studio.set("accessibility_name", Strings.t("loading_studio"))
	column.add_child(studio)
	App.loading_progressed.connect(_on_progress)
	_progress = App.loading_progress
	set_process(true)


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _on_progress(value: float, label_key: String) -> void:
	_progress = value
	_step_label.text = Strings.t(label_key)


func _process(delta: float) -> void:
	_elapsed += delta
	# La barre suit la progression réelle mais s'étale sur la durée minimale : jamais plus vite que la réalité.
	var paced := Motion.ease_in_out_cubic(clampf(_elapsed / BAR_SECONDS, 0.0, 1.0))
	var target := minf(_progress, paced)
	_shown += (target - _shown) * (1.0 - exp(-10.0 * delta))
	if _progress >= 1.0 and paced >= 1.0:
		_shown = 1.0
	_bar.set_fraction(_shown)
