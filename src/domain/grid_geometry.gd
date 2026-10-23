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
