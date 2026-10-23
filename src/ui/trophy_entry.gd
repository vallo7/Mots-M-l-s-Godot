class_name TrophyEntry
extends JuicyPressable
## Bouton « Trophées » de l'accueil, sous le carrousel : trophée doré, titre, « n / 20 débloqués », chevron. Une pastille
## rose indique le nombre de trophées débloqués pas encore consultés.

const HEIGHT := 64.0

var _subtitle: Label
var _badge: Label
var _unlocked := 0
var _total := 0
var _unseen := 0


static func create(unlocked: int, total: int, unseen: int) -> TrophyEntry:
	var entry := TrophyEntry.new()
	entry._build()
	entry.apply(unlocked, total, unseen)
	return entry


func _build() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	squash = 0.4
	sound = Sound.MENU_CHANGE
	haptic = HapticEffect.SELECTION
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	UiKit.full_rect(row)
	row.offset_left = 14.0
	row.offset_right = -16.0
	row.offset_top = 2.0
	row.offset_bottom = -6.0
	add_child(row)
	var badge_holder := Control.new()
	badge_holder.custom_minimum_size = Vector2(46.0, 46.0)
	badge_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UiKit.icon("ic_trophy", 42.0)
	UiKit.full_rect(icon)
	badge_holder.add_child(icon)
	_badge = Wg.label("", 11.0, Wg.Weight.BLACK, Wg.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = Wg.PINK
	box.set_corner_radius_all(999)
	box.anti_aliasing = true
	box.border_color = Wg.SURFACE
	box.set_border_width_all(2)
	box.content_margin_left = 5.0
	box.content_margin_right = 5.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	_badge.add_theme_stylebox_override("normal", box)
	_badge.custom_minimum_size = Vector2(20.0, 20.0)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -18.0
	_badge.offset_right = 6.0
	_badge.offset_top = -6.0
	_badge.offset_bottom = 14.0
	badge_holder.add_child(_badge)
	row.add_child(badge_holder)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Wg.label(Strings.t("trophies_title"), 19.0, Wg.Weight.BLACK, Wg.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(title)
	_subtitle = Wg.label("", 13.0, Wg.Weight.BOLD, Wg.INK_MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_subtitle)
	row.add_child(texts)
	var chevron := UiKit.icon("ic_chevron", 22.0, Wg.INK_MUTED)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)


## Met le bouton à jour sans le reconstruire.
func apply(unlocked: int, total: int, unseen: int) -> void:
	_unlocked = unlocked
	_total = total
	_unseen = unseen
	_subtitle.text = Strings.t("trophies_summary", [unlocked, total])
	_badge.visible = unseen > 0
	_badge.text = str(unseen) if unseen < 10 else "9+"
	description = "%s. %s" % [Strings.t("trophies_title"), _subtitle.text]
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size - Vector2(0.0, 4.0))
	Wg.rrect(self, Rect2(r.position + Vector2(0.0, 4.0), r.size), Color(Wg.SHADOW, Wg.SHADOW.a * 0.8), 24.0)
	Wg.rrect(self, r, Wg.SURFACE, 24.0)
	Wg.rrect(self, r, Color(Wg.YELLOW, 0.10), 24.0)
	Wg.outline(self, r, Color(Wg.YELLOW, 0.9), 24.0, 2.5)
	_draw_focus_ring(r, 24.0)
