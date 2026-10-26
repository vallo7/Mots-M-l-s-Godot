class_name GridGeometry
extends RefCounted
## Géométrie du tracé : position tactile -> case, et alignement du tracé sur l'une des 8 directions.


## Case sous le point (x, y) ; les points hors grille sont ramenés sur la case de bord la plus proche.
static func cell_at(x: float, y: float, cell_size: float, size: int) -> Vector2i:
	if cell_size <= 0.0 or size <= 0:
		return Vector2i.ZERO
	var col := clampi(int(floorf(x / cell_size)), 0, size - 1)
	var row := clampi(int(floorf(y / cell_size)), 0, size - 1)
	return Vector2i(col, row)


## Direction (de 8) vers laquelle le tracé est orienté d'après la position exacte du doigt (`pointer`, en unités de case, repère de
## la grille). -1 tant que le doigt est encore près du centre de la case de départ. `previous` : direction précédente, conservée
## tant que le doigt reste à moins de 32° de son axe (zone d'hystérésis) : la ligne ne saute plus d'une direction à l'autre
## quand le doigt passe près d'une frontière.
const DEAD_ZONE := 0.5
const HYSTERESIS := PI / 8.0 + 0.15
## Direction de chaque octant de 45° (0 = est, puis dans le sens horaire à l'écran, y vers le bas).
const OCTANT_DIRECTIONS: Array[int] = [Direction.E, Direction.SE, Direction.S, Direction.SW, Direction.W, Direction.NW, Direction.N, Direction.NE]


static func direction_for(start: Vector2i, pointer: Vector2, previous: int = -1) -> int:
	var v := pointer - (Vector2(start) + Vector2(0.5, 0.5))
	if v.length() < DEAD_ZONE:
		return -1
	var angle := v.angle()
	if previous >= 0 and absf(angle_difference(Vector2(Direction.vector(previous)).angle(), angle)) <= HYSTERESIS:
		return previous
	return OCTANT_DIRECTIONS[posmod(roundi(angle / (PI / 4.0)), 8)]


## Nombre de cases à parcourir depuis `start` dans `direction` pour suivre le doigt (projeté sur l'axe), borné par le bord de la grille.
static func length_for(start: Vector2i, pointer: Vector2, direction: int, size: int) -> int:
	var step := Vector2(Direction.vector(direction))
	var v := pointer - (Vector2(start) + Vector2(0.5, 0.5))
	var along := v.dot(step.normalized()) / step.length()  # en pas (1 case en ligne droite, 1,41 case en diagonale)
	return clampi(roundi(along + 0.08), 0, room_along(start, direction, size))


## Cases disponibles entre `start` et le bord de la grille dans `direction`.
static func room_along(start: Vector2i, direction: int, size: int) -> int:
	var step := Direction.vector(direction)
	var room := 1 << 20
	if step.x > 0:
		room = mini(room, size - 1 - start.x)
	elif step.x < 0:
		room = mini(room, start.x)
	if step.y > 0:
		room = mini(room, size - 1 - start.y)
	elif step.y < 0:
		room = mini(room, start.y)
	return maxi(room, 0)


static func path_along(start: Vector2i, direction: int, length: int, size: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [start]
	if direction < 0:
		return result
	var step := Direction.vector(direction)
	for i in range(1, mini(length, room_along(start, direction, size)) + 1):
		result.append(start + step * i)
	return result


## Tracé aligné de `start` vers `current` : horizontal, vertical ou diagonal, toujours dans la grille.
static func snap_path(start: Vector2i, current: Vector2i, size: int) -> Array[Vector2i]:
	var dr := current.y - start.y
	var dc := current.x - start.x
	var result: Array[Vector2i] = []
	if dr == 0 and dc == 0:
		result.append(start)
		return result
	var adr := absi(dr)
	var adc := absi(dc)
	var step := Vector2i.ZERO
	var length := 0
	if adr >= 2 * adc:
		step = Vector2i(0, signi(dr))
		length = adr
	elif adc >= 2 * adr:
		step = Vector2i(signi(dc), 0)
		length = adc
	else:
		step = Vector2i(signi(dc), signi(dr))
		var room_r := (size - 1 - start.y) if step.y > 0 else start.y
		var room_c := (size - 1 - start.x) if step.x > 0 else start.x
		length = mini(maxi(adr, adc), mini(room_r, room_c))
	for i in range(length + 1):
		result.append(start + step * i)
	return result
