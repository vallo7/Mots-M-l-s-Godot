class_name CreditsPopup
extends RefCounted
## Crédits : version, jeu, audio, bibliothèques, publicités, confidentialité.


static func open(parent: Node) -> PopupHost:
	var card := PopupCard.create(Strings.t("credits_title"), "blue", true, Strings.t("cd_close"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(Wg.SP_MD))
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	card.body.add_child(scroll)
	var name_label := Wg.label(Strings.t("app_name"), 28.0, Wg.Weight.BLACK, Wg.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(name_label)
	var version := Wg.label(Strings.t("credits_version", [str(ProjectSettings.get_setting("application/config/version", "1.2.1"))]), 16.0, Wg.Weight.EXTRABOLD, Wg.INK_MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	version.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(version)
	for pair in [
		["credits_section_studio", "credits_studio_body"],
		["credits_section_game", "credits_game_body"], ["credits_section_audio", "credits_audio_body"],
		["credits_section_libs", "credits_libs_body"], ["credits_section_ads", "credits_ads_body"],
		["credits_section_privacy", "credits_privacy_body"],
	]:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", int(Wg.SP_XS))
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var heading := Wg.label(Strings.t(pair[0]), 18.0, Wg.Weight.EXTRABOLD, Wg.INK)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(heading)
		var body_text := Strings.t(pair[1])
		if pair[1] == "credits_ads_body" and App.ads != null:
			body_text += "\n\n" + Strings.t("credits_ads_source_%s" % App.ads.provider_id())
		var body := Wg.label(body_text, 14.0, Wg.Weight.BOLD, Wg.INK_MUTED)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(body)
		list.add_child(section)
	var copyright := Wg.label(Strings.t("credits_studio_copyright"), 13.0, Wg.Weight.BOLD, Color(Wg.INK_MUTED, 0.85))
	copyright.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(copyright)
	var host := PopupHost.open(parent, card)
	host.set_scroll_region(scroll, list, PopupCard.CHROME_HEIGHT)
	card.close_pressed.connect(App.on_back)
	host.dismissed.connect(App.on_back)
	return host
