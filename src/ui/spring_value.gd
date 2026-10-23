class_name SpringValue
extends RefCounted
## Ressort amorti intégré pas à pas (mêmes paramètres que les ressorts de Compose : raideur et
## taux d'amortissement). Sert aux animations interactives dont la cible change en cours de route.

var value: float = 0.0
var velocity: float = 0.0
var target: float = 0.0
var stiffness: float = 620.0
var damping_ratio: float = 0.36


func _init(p_stiffness: float = 620.0, p_damping_ratio: float = 0.36, p_value: float = 0.0) -> void:
	stiffness = p_stiffness
	damping_ratio = p_damping_ratio
	value = p_value
	target = p_value


func snap_to(v: float) -> void:
	value = v
	target = v
	velocity = 0.0


func is_settled() -> bool:
	return absf(value - target) < 0.0005 and absf(velocity) < 0.005


## Avance de `delta` secondes (sous-pas fixes : stable même à basse fréquence d'images).
func step(delta: float) -> void:
	if Wg.reduce_motion:
		snap_to(target)
		return
	var omega := sqrt(stiffness)
	var remaining := minf(delta, 0.1)
	while remaining > 0.0:
		var dt := minf(remaining, 1.0 / 240.0)
		var accel := -stiffness * (value - target) - 2.0 * damping_ratio * omega * velocity
		velocity += accel * dt
		value += velocity * dt
		remaining -= dt
	if is_settled():
		snap_to(target)
