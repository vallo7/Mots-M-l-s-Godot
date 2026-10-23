class_name TrophyTile
extends JuicyPressable
## Une case de la grille des trophées : l'icône (couleur de la rareté, ou gris + cadenas tant que le trophée est
## verrouillé), son nom, et pour un trophée verrouillé déjà entamé une fine barre d'avancement. Un appui l'ouvre.

const HEIGHT := 138.0
const ICON_SIZE := 62.0

var trophy: Trophy
var unlocked := false
var is_new := false
var _fraction := 0.0
var _progress: int = 0


static func create(p_trophy: Trophy, p_unlocked: bool, p_progress: int, p_is_new: bool) -> TrophyTile:
	var tile := TrophyTile.new()
	tile.trophy = p_trophy
	tile.unlocked = p_unlocked
	tile.is_new = p_is_new
	tile._progress = p_progress
	tile._fraction = clampf(float(p_progress) / maxi(p_trophy.target, 1), 0.0, 1.0)
	tile._build()
	return tile


func _build() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	squash = 0.5
	sound = Sound.MENU_CHANGE
	haptic = HapticEffect.SELECTION
	var title := TrophyStyle.title(trophy)
	var status := TrophyStyle.tier_name(trophy.tier) if unlocked else Strings.t("trophy_locked")
	description = "%s. %s" % [title, status]
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	UiKit.full_rect(column)
	column.offset_left = 6.0
	column.offset_right = -6.0
	column.offset_top = 10.0
	column.offset_bottom = -14.0
	add_child(column)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(0.0, ICON_SIZE)
	icon_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UiKit.icon(trophy.icon_name() if unlocked else Trophy.LOCKED_ICON, ICON_SIZE)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -ICON_SIZE * 0.5
	icon.offset_right = ICON_SIZE * 0.5
	icon.offset_top = -ICON_SIZE * 0.5
	icon.offset_bottom = ICON_SIZE * 0.5
	if not unlocked:
		icon.self_modulate = Color(1.0, 1.0, 1.0, 0.92)
	icon_holder.add_child(icon)
	if not unlocked:
		# Petit cadenas sur le pied du trophée
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(22.0, 22.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		badge.offset_left = 10.0
		badge.offset_right = 32.0
		badge.offset_top = 10.0
		badge.offset_bottom = 32.0
		var disc := _LockDisc.new()
		UiKit.full_rect(disc)
		badge.add_child(disc)
		var glyph := UiKit.icon("ic_lock", 13.0, Wg.WHITE)
		glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		glyph.offset_left = -6.5
		glyph.offset_right = 6.5
		glyph.offset_top = -6.5
		glyph.offset_bottom = 6.5
		badge.add_child(glyph)
		icon_holder.add_child(badge)
	column.add_child(icon_holder)

	var name_label := Wg.label(title, 12.0, Wg.Weight.EXTRABOLD, Wg.INK if unlocked else Wg.INK_MUTED)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(0.0, 32.0 * Wg.text_scale)
	column.add_child(name_label)

	var footer := Control.new()
	footer.custom_minimum_size = Vector2(0.0, 8.0)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked and _fraction > 0.0:
		var bar := ChunkyProgressBar.create(_fraction, TrophyStyle.tier_color(trophy.tier), TrophyStyle.tier_color(trophy.tier).darkened(0.25), 8.0)
		UiKit.full_rect(bar)
		bar.offset_left = 12.0
		bar.offset_right = -12.0
		footer.add_child(bar)
	column.add_child(footer)

	if is_new:
		var tag := Wg.label(Strings.t("trophy_new"), 10.0, Wg.Weight.BLACK, Wg.WHITE)
		var box := StyleBoxFlat.new()
		box.bg_color = Wg.PINK
		box.set_corner_radius_all(9)
		box.anti_aliasing = true
		box.content_margin_left = 6.0
		box.content_margin_right = 6.0
		box.content_margin_top = 1.0
		box.content_margin_bottom = 1.0
		tag.add_theme_stylebox_override("normal", box)
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_left = -tag.get_minimum_size().x - 4.0
		tag.offset_right = -4.0
		tag.offset_top = 4.0
		add_child(tag)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size - Vector2(0.0, 4.0))
	var accent := TrophyStyle.tier_color(trophy.tier)
	Wg.rrect(self, Rect2(r.position + Vector2(0.0, 4.0), r.size), Color(Wg.SHADOW, Wg.SHADOW.a * 0.8), 22.0)
	Wg.rrect(self, r, Wg.SURFACE, 22.0)
	if unlocked:
		Wg.rrect(self, r, Color(accent, 0.12), 22.0)
		Wg.outline(self, r, Color(accent, 0.85), 22.0, 2.5)
	else:
		Wg.outline(self, r, Wg.OUTLINE, 22.0, 2.0)
	_draw_focus_ring(r, 22.0)


## Disque sombre derrière le cadenas.
class _LockDisc extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Wg.LOCKED_INK, true, -1.0, true)
