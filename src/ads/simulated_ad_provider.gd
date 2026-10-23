class_name SimulatedAdProvider
extends AdProvider
## Publicités de TEST SIMULÉES. Utilisées quand le plugin AdMob n'est pas installé dans un build de debug (éditeur, APK
## de test sans plugin) : tout le parcours publicitaire reste visible et testable — bannière, annonce récompensée
## (+1 indice seulement si on va au bout), annonce de retour — sans réseau ni SDK. Jamais utilisées dans un build de
## release (voir App._create_ads) : un vrai build de publication n'affiche aucune fausse annonce.

const REWARD_SECONDS := 5.0
const RETURN_SECONDS := 3.0
## Délai avant que le bouton de fermeture anticipée apparaisse.
const SKIP_AFTER_SECONDS := 2.0
const BANNER_HEIGHT := 50.0

var _tree: SceneTree
var _banner_layer: CanvasLayer
var _showing := false


func _init(tree: SceneTree) -> void:
	_tree = tree


## Consentement inutile en simulation : les annonces sont toujours autorisées.
func start() -> bool:
	return true


func rewarded_unavailable_reason() -> int:
	return UnavailableReason.NONE


func show_rewarded() -> RewardedAdResult:
	if _showing:
		return RewardedAdResult.unavailable(UnavailableReason.NOT_LOADED)
	var completed: bool = await _show_overlay(true)
	if completed:
		return RewardedAdResult.rewarded("sim-%d" % Time.get_ticks_usec())
	return RewardedAdResult.dismissed()


func show_return_ad_if_ready() -> bool:
	if _showing:
		return false
	await _show_overlay(false)
	return true


func is_full_screen_ad_showing() -> bool:
	return _showing


func set_banner_visible(is_visible: bool) -> void:
	if is_visible and _banner_layer == null:
		_banner_layer = CanvasLayer.new()
		_banner_layer.layer = 90
		var banner := _Banner.new()
		banner.bottom_inset = App.safe_area_insets.w
		_banner_layer.add_child(banner)
		_tree.root.add_child(_banner_layer)
	elif not is_visible and _banner_layer != null:
		_banner_layer.queue_free()
		_banner_layer = null


func privacy_options_required() -> bool:
	return false


func _show_overlay(rewarded: bool) -> bool:
	_showing = true
	var layer := CanvasLayer.new()
	layer.layer = 100
	var overlay := _Overlay.new()
	overlay.rewarded = rewarded
	layer.add_child(overlay)
	_tree.root.add_child(layer)
	var completed: bool = await overlay.finished
	layer.queue_free()
	_showing = false
	return completed


## Bandeau du bas, à l'emplacement de la zone réservée de la grille.
class _Banner extends Control:
	var bottom_inset := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		offset_top = -(BANNER_HEIGHT + bottom_inset)
		offset_bottom = -bottom_inset

	func _draw() -> void:
		Wg.rrect(self, Rect2(8.0, 3.0, size.x - 16.0, size.y - 6.0), Wg.TRACK, 12.0)
		var font := Wg.font(Wg.Weight.EXTRABOLD)
		var text := Strings.t("ad_test_banner")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.5 + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Wg.INK_MUTED)
		Wg.rrect(self, Rect2(14.0, 8.0, 28.0, 16.0), Wg.YELLOW, 8.0)
		draw_string(Wg.font(Wg.Weight.BLACK), Vector2(19.0, 20.0), "Ad", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Wg.INK_FIXED)


## Annonce plein écran : compte à rebours, puis bouton pour récupérer la récompense. Fermeture anticipée possible
## après un court délai (sans récompense). Aucun fondu.
class _Overlay extends Control:
	signal finished(completed: bool)

	var rewarded := true
	var _elapsed := 0.0
	var _total := 5.0
	var _done := false
	var _skip: WgButton
	var _claim: WgButton

	func _ready() -> void:
		_total = REWARD_SECONDS if rewarded else RETURN_SECONDS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_END
		column.add_theme_constant_override("separation", 10)
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 28.0
		column.offset_right = -28.0
		column.offset_bottom = -(36.0 + App.safe_area_insets.w)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		_claim = WgButton.create(Strings.t("ad_test_claim") if rewarded else Strings.t("ad_test_close"), WgButton.Kind.PRIMARY, "", true)
		_claim.visible = false
		_claim.activated.connect(func() -> void: _finish(true))
		_skip = WgButton.create(Strings.t("ad_test_skip") if rewarded else Strings.t("ad_test_close"), WgButton.Kind.GHOST)
		_skip.visible = false
		_skip.activated.connect(func() -> void: _finish(not rewarded))
		column.add_child(_claim)
		column.add_child(_skip)
		set_process(true)

	func _finish(completed: bool) -> void:
		if _done and not completed and rewarded:
			return
		set_process(false)
		finished.emit(completed)

	func _process(delta: float) -> void:
		_elapsed += delta
		_skip.visible = _elapsed >= SKIP_AFTER_SECONDS and _elapsed < _total
		if _elapsed >= _total and not _done:
			_done = true
			_skip.visible = false
			_claim.visible = true
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color8(0x1B, 0x17, 0x3F))
		var center := Vector2(size.x * 0.5, size.y * 0.38)
		var font := Wg.font(Wg.Weight.BLACK)
		# Pastille « annonce de test »
		var badge := Strings.t("ad_test_badge")
		var badge_w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0
		Wg.rrect(self, Rect2(center.x - badge_w * 0.5, center.y - 180.0, badge_w, 30.0), Wg.YELLOW, 15.0)
		draw_string(font, Vector2(center.x - badge_w * 0.5 + 14.0, center.y - 159.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Wg.INK_FIXED)
		var title := Strings.t("ad_test_rewarded_title") if rewarded else Strings.t("ad_test_return_title")
		var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2(center.x - minf(title_w, size.x - 40.0) * 0.5, center.y - 112.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40.0, 20, Color.WHITE)
		# Anneau de progression
		var fraction := clampf(_elapsed / _total, 0.0, 1.0)
		draw_arc(center, 64.0, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 12.0, true)
		draw_arc(center, 64.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, 64, Wg.YELLOW if not _done else Wg.GREEN, 12.0, true)
		var seconds := int(ceil(maxf(_total - _elapsed, 0.0)))
		var label := Strings.t("ad_test_wait", [seconds]) if not _done else "✓"
		var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		draw_string(font, Vector2(center.x - label_w * 0.5, center.y + 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
		var hint := Strings.t("ad_test_rewarded_hint") if rewarded else Strings.t("ad_test_return_hint")
		var hint_font := Wg.font(Wg.Weight.BOLD)
		var hint_w := hint_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - 56.0, 16).x
		draw_string(hint_font, Vector2(center.x - minf(hint_w, size.x - 56.0) * 0.5, center.y + 118.0), hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - 56.0, 16, Color(1, 1, 1, 0.8))
