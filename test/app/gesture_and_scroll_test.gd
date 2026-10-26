class_name GestureAndScrollTest
extends GdUnitTestSuite
## Tracé continu (angle + projection), gamme montante, défilement à inertie, carrousel, rotation visuelle de la grille.

const _N := 8


# ---- Tracé continu
func test_the_finger_inside_the_start_cell_does_not_start_a_line() -> void:
	var start := Vector2i(3, 3)
	assert_int(GridGeometry.direction_for(start, Vector2(3.5, 3.5))).is_equal(-1)
	assert_int(GridGeometry.direction_for(start, Vector2(3.6, 3.55))).is_equal(-1)  # légère dérive : toujours rien


func test_direction_follows_the_exact_angle_in_45_degree_sectors() -> void:
	var start := Vector2i(3, 3)
	var center := Vector2(3.5, 3.5)
	assert_int(GridGeometry.direction_for(start, center + Vector2(2.0, 0.1))).is_equal(Direction.E)
	assert_int(GridGeometry.direction_for(start, center + Vector2(2.0, 1.5))).is_equal(Direction.SE)
	assert_int(GridGeometry.direction_for(start, center + Vector2(0.2, 2.0))).is_equal(Direction.S)
	assert_int(GridGeometry.direction_for(start, center + Vector2(-1.4, 1.5))).is_equal(Direction.SW)
	assert_int(GridGeometry.direction_for(start, center + Vector2(-2.0, 0.0))).is_equal(Direction.W)
	assert_int(GridGeometry.direction_for(start, center + Vector2(-1.5, -1.4))).is_equal(Direction.NW)
	assert_int(GridGeometry.direction_for(start, center + Vector2(0.0, -2.0))).is_equal(Direction.N)
	assert_int(GridGeometry.direction_for(start, center + Vector2(1.5, -1.5))).is_equal(Direction.NE)


func test_the_line_does_not_flicker_near_a_boundary_thanks_to_hysteresis() -> void:
	var start := Vector2i(2, 2)
	var center := Vector2(2.5, 2.5)
	# Frontière E / SE : 22,5°. Un doigt à 25° choisit SE depuis rien…
	var angle_pointer := center + Vector2.from_angle(deg_to_rad(25.0)) * 2.5
	assert_int(GridGeometry.direction_for(start, angle_pointer)).is_equal(Direction.SE)
	# …mais s'il venait de E, il reste sur E jusqu'à 32° environ.
	assert_int(GridGeometry.direction_for(start, angle_pointer, Direction.E)).is_equal(Direction.E)
	var far := center + Vector2.from_angle(deg_to_rad(40.0)) * 2.5
	assert_int(GridGeometry.direction_for(start, far, Direction.E)).is_equal(Direction.SE)  # bien au-delà : il change


func test_length_follows_the_finger_along_the_axis_and_stops_at_the_grid_edge() -> void:
	var start := Vector2i(1, 1)
	assert_int(GridGeometry.length_for(start, Vector2(3.5, 1.5), Direction.E, _N)).is_equal(2)
	assert_int(GridGeometry.length_for(start, Vector2(3.0, 1.5), Direction.E, _N)).is_equal(2)  # à mi-chemin de la 3e case : on y arrive
	assert_int(GridGeometry.length_for(start, Vector2(2.0, 1.5), Direction.E, _N)).is_equal(1)
	assert_int(GridGeometry.length_for(start, Vector2(99.0, 1.5), Direction.E, _N)).is_equal(_N - 2)  # bord de grille
	assert_int(GridGeometry.length_for(start, Vector2(-5.0, 1.5), Direction.W, _N)).is_equal(1)
	# Diagonale : un pas = une case en colonne ET en ligne
	assert_int(GridGeometry.length_for(start, Vector2(3.5, 3.5), Direction.SE, _N)).is_equal(2)
	assert_int(GridGeometry.length_for(start, Vector2(20.0, 20.0), Direction.SE, _N)).is_equal(_N - 2)


func test_path_along_lists_the_cells_in_order_and_never_leaves_the_grid() -> void:
	var path := GridGeometry.path_along(Vector2i(0, 0), Direction.SE, 3, _N)
	assert_array(path).contains_exactly([Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)])
	assert_array(GridGeometry.path_along(Vector2i(6, 6), Direction.E, 10, _N)).has_size(2)
	assert_array(GridGeometry.path_along(Vector2i(4, 4), -1, 3, _N)).contains_exactly([Vector2i(4, 4)])


func test_a_slightly_wobbly_horizontal_drag_stays_a_clean_horizontal_line() -> void:
	var start := Vector2i(0, 3)
	var direction := -1
	for step in range(1, 60):
		var x := 0.5 + step * 0.1
		var y := 3.5 + sin(step * 1.3) * 0.13  # tremblement vertical réaliste d'un doigt (≈ 5 dp)
		direction = GridGeometry.direction_for(start, Vector2(x, y), direction)
		if x > 1.6:  # une fois le doigt clairement parti (plus d'une case), la direction est stable
			assert_int(direction).is_equal(Direction.E)
	assert_int(direction).is_equal(Direction.E)


# ---- Gamme montante
func test_each_new_letter_plays_one_note_higher_up_to_one_and_a_half_octaves() -> void:
	assert_float(GameController.select_pitch(1)).is_equal(1.0)
	var last := 1.0
	for size in range(2, 9):
		var pitch := GameController.select_pitch(size)
		assert_float(pitch).is_greater(last)
		last = pitch
	assert_float(GameController.select_pitch(8)).is_equal_approx(pow(2.0, 16.0 / 12.0), 0.001)
	assert_float(GameController.select_pitch(40)).is_equal(GameController.select_pitch(8))  # plafond : jamais de couinement


# ---- Défilement à inertie
func test_a_fast_finger_gives_a_fling_a_stopped_finger_gives_none() -> void:
	var samples: Array[Vector2] = [Vector2(1000, 600), Vector2(1030, 570), Vector2(1060, 540), Vector2(1090, 510)]  # doigt vers le haut, 1000 px/s
	assert_float(SmoothScroll.fling_velocity(samples, 1095)).is_equal_approx(1000.0, 5.0)  # le contenu monte
	assert_float(SmoothScroll.fling_velocity(samples, 1400)).is_equal(0.0)  # le doigt s'est arrêté avant de se lever
	var down: Array[Vector2] = [Vector2(1000, 300), Vector2(1050, 350)]
	assert_float(SmoothScroll.fling_velocity(down, 1055)).is_less(0.0)
	assert_float(SmoothScroll.fling_velocity([Vector2(1000, 300)] as Array[Vector2], 1010)).is_equal(0.0)


func test_the_list_stretches_with_resistance_beyond_its_ends() -> void:
	var scroll := SmoothScroll.new()
	scroll.size = Vector2(300.0, 600.0)
	var content := Control.new()
	content.custom_minimum_size = Vector2(300.0, 1800.0)
	scroll.add_child(content)
	add_child(scroll)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(scroll.max_scroll()).is_equal_approx(1200.0, 1.0)
	assert_float(scroll.rubber_offset(500.0)).is_equal(500.0)  # dans la liste : 1:1
	var stretched := scroll.rubber_offset(-200.0)
	assert_float(stretched).is_less(0.0)
	assert_float(stretched).is_greater(-200.0)  # résistance : on tire 200, ça ne suit pas 200
	assert_float(scroll.rubber_offset(-2000.0)).is_greater(-600.0)  # jamais plus d'une hauteur d'écran
	assert_float(scroll.rubber_offset(1200.0 + 200.0)).is_between(1200.0, 1400.0)
	scroll.scroll_position = 5000.0
	assert_float(scroll.scroll_position).is_equal(1200.0)  # borné
	scroll.scroll_vertical = 300
	assert_float(content.position.y).is_equal_approx(-300.0, 0.01)
	scroll.free()


# ---- Carrousel
func test_a_short_slow_drag_returns_and_a_long_or_fast_one_changes_page() -> void:
	assert_int(ChapterPager.target_page(2, 2.1, 0.0, 5)).is_equal(2)  # petit déplacement lent : retour
	assert_int(ChapterPager.target_page(2, 2.4, 0.0, 5)).is_equal(3)  # plus d'un quart de page : on avance
	assert_int(ChapterPager.target_page(2, 1.6, 0.0, 5)).is_equal(1)
	assert_int(ChapterPager.target_page(2, 2.08, 1.6, 5)).is_equal(3)  # petit coup de doigt rapide
	assert_int(ChapterPager.target_page(2, 1.92, -1.6, 5)).is_equal(1)


func test_the_carousel_never_skips_more_than_one_page_and_stays_in_range() -> void:
	assert_int(ChapterPager.target_page(1, 3.4, 8.0, 5)).is_equal(2)  # geste énorme : une page seulement
	assert_int(ChapterPager.target_page(0, -0.5, -4.0, 5)).is_equal(0)  # avant la première : reste
	assert_int(ChapterPager.target_page(4, 4.6, 4.0, 5)).is_equal(4)  # après la dernière : reste
	assert_int(ChapterPager.target_page(0, 0.0, 0.0, 1)).is_equal(0)


func test_a_fast_flick_against_the_drag_direction_does_not_flip_the_page() -> void:
	# On a tiré vers la page suivante (+0,5) mais le doigt repart vite en arrière : on suit l'intention finale… sauf geste hésitant.
	assert_int(ChapterPager.target_page(2, 2.5, -0.3, 5)).is_equal(3)  # vitesse trop faible pour annuler
	assert_int(ChapterPager.target_page(2, 2.5, 1.2, 5)).is_equal(3)


# ---- Rotation visuelle de la grille
func test_restarting_the_grid_starts_each_letter_at_its_old_position() -> void:
	var fx := GridFx.new(4, false)
	fx.on_restart(1, 7)
	assert_bool(fx.is_shuffling()).is_true()
	var now := Time.get_ticks_msec()
	fx.clock_ms = now
	fx.tick(now)
	fx._compute_letter_effects(now)
	# Tour à droite : la lettre maintenant en (x, y) venait de la case tournée en sens inverse.
	for y in range(4):
		for x in range(4):
			var idx := y * 4 + x
			var old := LevelVariant.rotate_cell(Vector2i(x, y), 4, -1)
			var expected := Vector2(old) - Vector2(x, y)
			assert_float((fx._off[idx] as Vector2).distance_to(expected)).is_less(0.05)


func test_restart_letters_end_exactly_on_their_cells_then_the_effect_stops() -> void:
	var fx := GridFx.new(4, false)
	fx.on_restart(-1, 3)
	var start := Time.get_ticks_msec()
	fx.tick(start)
	var end := start + GridFx.SHUFFLE_TOTAL_MS + 60
	fx.tick(end)
	assert_bool(fx.is_shuffling()).is_false()
	fx._compute_letter_effects(end)
	for idx in range(16):
		assert_int(fx._touched[idx]).is_equal(0)  # plus aucune lettre animée : tout est à sa place


func test_restart_motion_is_skipped_when_animations_are_reduced() -> void:
	var fx := GridFx.new(4, true)
	fx.on_restart(1, 1)
	assert_bool(fx.is_shuffling()).is_false()


func test_letters_move_along_their_square_ring_like_a_belt_and_never_leave_the_grid() -> void:
	# Grille de 4 : un quart de tour horaire envoie le coin haut-gauche (-1,5 ; -1,5) au coin haut-droit (1,5 ; -1,5).
	var start := GridFx._ring_move(Vector2(-1.5, -1.5), 0.0)
	assert_vector(start).is_equal_approx(Vector2(-1.5, -1.5), Vector2(0.001, 0.001))
	assert_vector(GridFx._ring_move(Vector2(-1.5, -1.5), 1.0)).is_equal_approx(Vector2(1.5, -1.5), Vector2(0.001, 0.001))
	assert_vector(GridFx._ring_move(Vector2(-1.5, -1.5), -1.0)).is_equal_approx(Vector2(-1.5, 1.5), Vector2(0.001, 0.001))
	assert_vector(GridFx._ring_move(Vector2(-0.5, -0.5), 1.0)).is_equal_approx(Vector2(0.5, -0.5), Vector2(0.001, 0.001))  # couronne intérieure
	assert_vector(GridFx._ring_move(Vector2.ZERO, 0.7)).is_equal(Vector2.ZERO)  # grille impaire : le centre ne bouge pas
	for step in range(0, 41):
		var quarter := step / 40.0
		for v in [Vector2(-2.0, -2.0), Vector2(1.0, -2.0), Vector2(2.0, 0.0), Vector2(-1.0, 1.0)]:
			var moved := GridFx._ring_move(v, quarter)
			var rho := maxf(absf(v.x), absf(v.y))
			assert_float(maxf(absf(moved.x), absf(moved.y))).is_equal_approx(rho, 0.001)  # reste sur sa couronne : jamais hors grille
	# Deux lettres voisines gardent leur espacement pendant tout le mouvement (aucun chevauchement)
	for step in range(0, 41):
		var quarter := step / 40.0
		var a := GridFx._ring_move(Vector2(-1.5, -1.5), quarter)
		var b := GridFx._ring_move(Vector2(-0.5, -1.5), quarter)
		assert_float(a.distance_to(b)).is_greater(0.7)
