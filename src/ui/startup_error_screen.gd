class_name StartupErrorScreen
extends Control
## Affiché si les données de niveaux sont absentes ou invalides (jamais en usage normal : elles sont validées au build).


static func create() -> StartupErrorScreen:
	return StartupErrorScreen.new()


func _ready() -> void:
	UiKit.full_rect(self)
	var background := ColorRect.new()
	background.color = Wg.BACKGROUND
	UiKit.full_rect(background)
	add_child(background)
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(Wg.SP_XL))
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(Wg.SP_MD))
	margin.add_child(column)
	var title := Wg.label(Strings.t("loading_error_title"), 34.0, Wg.Weight.BLACK, Wg.ERROR)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var body := Wg.label(Strings.t("loading_error_body"), 16.0, Wg.Weight.BOLD, Wg.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
