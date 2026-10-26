class_name Motion
extends RefCounted
## Mathématiques de mouvement pures : ressorts amortis analytiques, courbes d'accélération et arcs.
## L'interface les évalue à chaque image à partir d'un temps écoulé : aucune animation par case,
## aucun état par élément, donc fluide même sur une grille 12×12.


static func clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


## Réponse en échelon d'un ressort amorti : 0 à t = 0 puis tend vers 1 en dépassant 1 (rebond) si
## `damping` < 1. `frequency` en rad/s (≈ 10 = mou, ≈ 22 = nerveux), `damping` ∈ (0, ∞) (≈ 0,45 = bien rebondissant).
static func spring(t: float, frequency: float = 16.0, damping: float = 0.5) -> float:
	if t <= 0.0:
		return 0.0
	var w := frequency
	var z := damping
	if z < 1.0:
		var wd := w * sqrt(1.0 - z * z)
		return 1.0 - exp(-z * w * t) * (cos(wd * t) + (z * w / wd) * sin(wd * t))
	return 1.0 - exp(-w * t) * (1.0 + w * t)


## Durée (s) au bout de laquelle le ressort est à moins de `tolerance` de sa cible : sert à arrêter la boucle d'images.
static func spring_settle_seconds(frequency: float = 16.0, damping: float = 0.5, tolerance: float = 0.01) -> float:
	return -log(tolerance) / (minf(damping, 1.0) * frequency)


## Départ lent, arrivée avec un léger dépassement (0..1 → 0..~1,1..1).
static func ease_out_back(t: float, overshoot: float = 1.70158) -> float:
	var x := clamp01(t) - 1.0
	return 1.0 + x * x * ((overshoot + 1.0) * x + overshoot)


static func ease_out_cubic(t: float) -> float:
	var x := 1.0 - clamp01(t)
	return 1.0 - x * x * x


static func ease_in_out_cubic(t: float) -> float:
	var x := clamp01(t)
	if x < 0.5:
		return 4.0 * x * x * x
	var y := -2.0 * x + 2.0
	return 1.0 - (y * y * y) / 2.0


## Bosse 0 → 1 → 0 (sinus) : impulsion de « squash » ou de saut.
static func bump(t: float) -> float:
	return sin(PI * clamp01(t))


## Point d'une courbe de Bézier quadratique (déplacements en arc des lettres).
static func quad(a: float, control: float, b: float, t: float) -> float:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * control + t * t * b


static func ease_in_cubic(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * c
