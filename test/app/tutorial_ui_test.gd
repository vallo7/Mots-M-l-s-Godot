class_name TutorialUiTest
extends GdUnitTestSuite
## Interface 1.3.0 : bannières image des popups, tutoriel du gant, marges de sécurité, bulles de chapitre sans bannière.


# ---- Bannières image
func test_banners_use_the_three_provided_images_and_legacy_names_map_to_them() -> void:
	for name in ["red", "yellow", "blue"]:
		assert_bool(ResourceLoader.exists(BannerImage.TEXTURES[name])).is_true()
	assert_str(BannerImage.resolve("red")).is_equal("red")
	assert_str(BannerImage.resolve("pink")).is_equal("red")
	assert_str(BannerImage.resolve("purple")).is_equal("blue")
	assert_str(BannerImage.resolve("n'importe quoi")).is_equal("blue")


func test_a_banner_keeps_its_proportions_and_puts_the_title_on_the_band() -> void:
	var banner := BannerImage.create("Réglages", "blue", 58.0)
	banner.size = Vector2(300.0, 58.0)
	add_child(banner)
	var image := banner.image_rect()
	assert_float(image.size.y).is_equal_approx(58.0, 0.5)
	assert_float(image.size.x / image.size.y).is_between(4.3, 4.9)  # proportions de l'image d'origine
	assert_float(image.get_center().x).is_equal_approx(150.0, 0.5)  # centrée
	assert_str(banner.get_title()).is_equal("Réglages")
	banner.free()


func test_every_popup_color_is_one_of_the_provided_banners() -> void:
	for ribbon in ["red", "yellow", "blue", "pink", "purple", "green"]:
		assert_bool(BannerImage.TEXTURES.has(BannerImage.resolve(ribbon))).is_true()


# ---- Marges de sécurité
func test_a_button_never_touches_the_safe_area_but_roomy_screens_are_unchanged() -> void:
	assert_int(UiKit.edge(0.0)).is_equal(int(Wg.EDGE_GAP))
	assert_int(UiKit.edge(4.0)).is_equal(int(Wg.EDGE_GAP))
	assert_int(UiKit.edge(8.0)).is_equal(int(Wg.EDGE_GAP))
	assert_int(UiKit.edge(16.0)).is_equal(16)  # déjà assez loin : inchangé
	assert_int(UiKit.edge(22.0)).is_equal(22)


# ---- Bulles de chapitre : plus de bannière
func _all_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_all_nodes(child))
	return nodes


func test_chapter_cards_have_no_ribbon_and_show_the_chapter_as_plain_text() -> void:
	var card := ChapterCard.new()
	card.index = 3
	card.palette_key = "meadow"
	card.status = ChapterStatus.CURRENT
	card.theme = {"fr": "Nature", "en": "Nature"}
	card.total = 10
	var view := ChapterCardView.create(card, Language.EN)
	add_child(view)
	var texts: Array[String] = []
	for node in _all_nodes(view):
		assert_bool(node is RibbonBanner).is_false()
		assert_bool(node is BannerImage).is_false()
		if node is Label:
			texts.append((node as Label).text)
	assert_bool(texts.has("Chapter 3")).is_true()
	view.free()


# ---- Tutoriel du gant
func test_the_tutorial_shows_the_remaining_words_one_after_the_other() -> void:
	assert_int(MoveTutorial.next_target([] as Array[int], 4)).is_equal(0)
	assert_int(MoveTutorial.next_target([0] as Array[int], 4)).is_equal(1)
	assert_int(MoveTutorial.next_target([1, 0] as Array[int], 4)).is_equal(2)  # l'ordre des mots trouvés n'a pas d'importance
	assert_int(MoveTutorial.next_target([0, 1, 2, 3] as Array[int], 4)).is_equal(-1)


func test_the_demo_loop_lasts_longer_for_longer_words() -> void:
	assert_float(MoveTutorial.period_for(3)).is_less(MoveTutorial.period_for(8))
	assert_float(MoveTutorial.drag_seconds(2)).is_equal(0.8)
	assert_float(MoveTutorial.drag_seconds(30)).is_equal(2.2)


func test_the_glove_enters_presses_on_the_first_letter_drags_to_the_last_and_leaves() -> void:
	var tutorial := MoveTutorial.new()
	var a := Vector2(100.0, 100.0)
	var b := Vector2(100.0, 220.0)
	var start := tutorial.pose(0.0, a, b, 3)
	assert_vector(start["tip"]).is_equal_approx(a + MoveTutorial.ENTER_OFFSET, Vector2(0.5, 0.5))
	assert_float(start["press"]).is_equal(0.0)
	assert_object(start["trail_to"]).is_null()  # pas encore de tracé
	var pressing := tutorial.pose(MoveTutorial.APPROACH + MoveTutorial.PRESS, a, b, 3)
	assert_vector(pressing["tip"]).is_equal_approx(a, Vector2(0.5, 0.5))
	assert_float(pressing["press"]).is_equal_approx(1.0, 0.01)
	var drag_end := MoveTutorial.APPROACH + MoveTutorial.PRESS + MoveTutorial.drag_seconds(3)
	var arrived := tutorial.pose(drag_end, a, b, 3)
	assert_vector(arrived["tip"]).is_equal_approx(b, Vector2(0.5, 0.5))
	assert_float(arrived["press"]).is_equal(1.0)
	assert_vector(arrived["trail_to"]).is_equal_approx(b, Vector2(0.5, 0.5))
	var mid := tutorial.pose(MoveTutorial.APPROACH + MoveTutorial.PRESS + MoveTutorial.drag_seconds(3) * 0.5, a, b, 3)
	assert_float((mid["tip"] as Vector2).y).is_between(a.y, b.y)  # le doigt glisse entre les deux lettres
	var gone := tutorial.pose(MoveTutorial.period_for(3) - 0.001, a, b, 3)
	assert_float(gone["press"]).is_equal(0.0)
	assert_object(gone["trail_to"]).is_null()
	tutorial.free()


func test_the_trail_is_a_single_convex_shape_around_both_letters() -> void:
	var a := Vector2(40.0, 40.0)
	var b := Vector2(140.0, 40.0)
	var shape := MoveTutorial.capsule_polygon(a, b, 20.0)
	assert_bool(Geometry2D.triangulate_polygon(shape).size() > 0).is_true()
	assert_bool(Geometry2D.is_point_in_polygon(a, shape)).is_true()
	assert_bool(Geometry2D.is_point_in_polygon(b, shape)).is_true()
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(90.0, 40.0), shape)).is_true()
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(90.0, 80.0), shape)).is_false()
	var dot := MoveTutorial.capsule_polygon(a, a, 20.0)  # un seul point : un disque
	assert_bool(Geometry2D.is_point_in_polygon(a, dot)).is_true()


func test_the_glove_image_is_the_projects_existing_one() -> void:
	assert_str(TutorialHand.TEXTURE_PATH).is_equal("res://assets/ui/tutorial-hand.png")
	assert_object(TutorialHand.texture()).is_not_null()
