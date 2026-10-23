class_name TrophyDetailPopup
extends RefCounted
## Fiche d'un trophée : grande icône, rareté, description, puis la date de déblocage ou l'avancement.


static func open(parent: Control, trophy: Trophy, state: ProgressState, catalog: LevelCatalog) -> PopupHost:
	var unlocked := TrophyRules.is_unlocked(state, trophy.id)
	var card := PopupCard.create(TrophyStyle.title(trophy), "yellow", true, Strings.t("cd_close"))
	var tier_color := TrophyStyle.tier_color(trophy.tier)

	var icon_holder := CenterContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.custom_minimum_size = Vector2(0.0, 150.0)
	var icon := UiKit.icon(trophy.icon_name() if unlocked else Trophy.LOCKED_ICON, 132.0)
	icon_holder.add_child(icon)
	card.body.add_child(icon_holder)

	var chip_holder := CenterContainer.new()
	chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := Wg.label(TrophyStyle.tier_name(trophy.tier), 13.0, Wg.Weight.BLACK, Wg.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = tier_color if unlocked else Wg.LOCKED_INK
	box.set_corner_radius_all(999)
	box.anti_aliasing = true
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	chip.add_theme_stylebox_override("normal", box)
	chip_holder.add_child(chip)
	card.body.add_child(chip_holder)
	card.body.add_child(_gap(12.0))

	var description := Wg.label(TrophyStyle.description(trophy), 17.0, Wg.Weight.BOLD, Wg.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(240.0, 0.0)
	card.body.add_child(description)
	card.body.add_child(_gap(14.0))

	if unlocked:
		var date := Wg.label(Strings.t("trophy_unlocked_on", [TrophyStyle.date_text(int(state.trophies[trophy.id]))]), 15.0, Wg.Weight.EXTRABOLD, Color(tier_color.r * 0.8, tier_color.g * 0.8, tier_color.b * 0.8))
		card.body.add_child(date)
	else:
		var progress := TrophyRules.progress_of(trophy, catalog, state)
		var bar := ChunkyProgressBar.create(float(progress) / maxi(trophy.target, 1), tier_color, tier_color.darkened(0.25), 18.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.body.add_child(bar)
		card.body.add_child(_gap(6.0))
		card.body.add_child(Wg.label(Strings.t("trophy_progress", [progress, trophy.target]), 15.0, Wg.Weight.EXTRABOLD, Wg.INK_MUTED))
	var host := PopupHost.open(parent, card)
	card.close_pressed.connect(host.close)
	host.dismissed.connect(host.close)
	Feedback.play(Sound.GIFT if unlocked else Sound.MENU_CHANGE)
	return host


static func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap
