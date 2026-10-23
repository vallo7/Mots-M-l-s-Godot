class_name UiFx
extends RefCounted
## Effets d'animation réutilisables : entrée en « pop » à ressort, petit rebond de compteur, balancement
## d'attention. Aucune animation de fondu. Tous respectent le réglage « animations réduites » (Wg.reduce_motion).

## Grandit de 0 à 1 avec un rebond ressort et une petite montée (cascade avec `delay`). À appliquer à un
## conteneur d'enveloppe, jamais à un élément qui utilise lui-même la pression « gelée ».
static func pop_in(node: Control, delay: float = 0.0, rise: float = 18.0, damping: float = 0.52, stiffness: float = 330.0) -> void:
	if Wg.reduce_motion or Wg.suppress_intro:
		return
	UiKit.jelly(node, 0.0, 0.0, rise)
	var omega := sqrt(stiffness)
	var duration := Motion.spring_settle_seconds(omega, damping, 0.003)
	var tween := node.create_tween()
	tween.tween_interval(maxf(delay, 0.0))
	tween.tween_method(func(t: float) -> void:
		var p := Motion.spring(t, omega, damping)
		UiKit.jelly(node, p, p, (1.0 - p) * rise), 0.0, duration, duration)
	tween.tween_callback(func() -> void: UiKit.jelly(node, 1.0, 1.0, 0.0))


## Petit rebond de pastille (compteur qui change) : le facteur monte à `from_scale` (~1,35) puis se pose.
static func bounce(node: Control, from_scale: float = 1.35, damping: float = 0.35, stiffness: float = 500.0) -> void:
	if Wg.reduce_motion:
		return
	var omega := sqrt(stiffness)
	var duration := Motion.spring_settle_seconds(omega, damping, 0.003)
	var tween := node.create_tween()
	tween.tween_method(func(t: float) -> void:
		var s := from_scale + (1.0 - from_scale) * Motion.spring(t, omega, damping)
		UiKit.jelly(node, s, s), 0.0, duration, duration)
	tween.tween_callback(func() -> void: UiKit.jelly(node, 1.0, 1.0))


## Petite bosse d'attention (rotation de part et d'autre) répétée toutes les ~3,2 s. Renvoie le Tween (à tuer pour l'arrêter).
static func wobble(node: Control) -> Tween:
	if Wg.reduce_motion:
		return null
	var tween := node.create_tween().set_loops()
	var steps := [[-14.0, 0.11], [12.0, 0.12], [-8.0, 0.12], [5.0, 0.12], [0.0, 0.13]]
	for step in steps:
		tween.tween_property(node, "offset_transform_rotation", deg_to_rad(step[0]), step[1]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(2.6)
	return tween
