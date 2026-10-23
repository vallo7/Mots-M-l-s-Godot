class_name GiftBadge
extends Control
## Cadeau de fin de chapitre (bulles de chapitre, victoire, monument). Quand il est prêt à être ouvert, il saute en boucle ;
## statique si animations réduites. (Le « trophée » désigne désormais les accomplissements : voir TrophyCatalog.)

var _wobble_tween: Tween


static func create(p_ready: bool, p_size: float = 44.0) -> GiftBadge:
	var badge := GiftBadge.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(p_size, p_size)
	var icon := UiKit.icon("ic_gift", p_size)
	UiKit.full_rect(icon)
	badge.add_child(icon)
	badge.set_ready_state(p_ready)
	return badge


func set_ready_state(p_ready: bool) -> void:
	if _wobble_tween != null:
		_wobble_tween.kill()
		_wobble_tween = null
	UiKit.jelly(self, 1.08 if p_ready else 1.0, 1.08 if p_ready else 1.0)
	if p_ready:
		_wobble_tween = UiFx.wobble(self)
