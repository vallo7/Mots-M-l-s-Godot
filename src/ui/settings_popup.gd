class_name SettingsPopup
extends PopupHost
## Paramètres : popup de la maquette « pause » (ruban en titre, bouton fermer rose, lignes avec interrupteur jaune).
## Tous les réglages s'appliquent immédiatement et sont conservés. La langue se choisit dans une liste dédiée, le volume
## des effets sonores et celui de la musique avec un curseur, et le mode sombre est un simple interrupteur.

var _rows: Dictionary = {}  ## clé de réglage -> ToggleRow
var _sfx: SliderRow
var _music: SliderRow
var _language: ChoiceRow


static func open_settings(parent: Node) -> SettingsPopup:
	var host := SettingsPopup.new()
	var card := PopupCard.create(Strings.t("settings_title"), "blue", true, Strings.t("cd_close"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	card.body.add_child(scroll)
	var s := App.settings

	# Langue : une ligne qui ouvre la liste dédiée
	host._language = ChoiceRow.create("ic_globe", Strings.t("settings_language"), _language_name())
	host._language.activated.connect(App.open_language)
	list.add_child(host._language)

	# Effets sonores : curseur de volume (appliqué en direct, enregistré au relâchement avec un clic témoin)
	host._sfx = SliderRow.create("ic_sound", Strings.t("settings_sound"), s.sfx_volume)
	host._sfx.previewed.connect(App.preview_sfx_volume)
	host._sfx.committed.connect(App.commit_sfx_volume)
	list.add_child(host._sfx)

	# Musique : curseur de volume (aperçu en direct, enregistré au relâchement)
	host._music = SliderRow.create("ic_music", Strings.t("settings_music"), s.music_volume)
	host._music.previewed.connect(App.preview_music_volume)
	host._music.committed.connect(App.commit_music_volume)
	list.add_child(host._music)

	host._add_toggle(list, "haptics", "ic_vibrate", Strings.t("settings_haptics"), "", s.haptics_enabled, func(v: bool) -> void:
		App.update_settings(func(x: AppSettings) -> AppSettings:
			var n := x.copy()
			n.haptics_enabled = v
			return n))

	list.add_child(_section(Strings.t("settings_appearance")))
	host._add_toggle(list, "dark_mode", "ic_moon", Strings.t("settings_dark_mode"), Strings.t("settings_dark_mode_hint"), s.dark_mode, func(v: bool) -> void:
		App.update_settings(func(x: AppSettings) -> AppSettings:
			var n := x.copy()
			n.dark_mode = v
			return n))

	list.add_child(_section(Strings.t("settings_accessibility")))
	host._add_toggle(list, "reduce_motion", "ic_motion", Strings.t("settings_reduce_motion"), Strings.t("settings_reduce_motion_hint"), s.reduce_motion, func(v: bool) -> void:
		App.update_settings(func(x: AppSettings) -> AppSettings:
			var n := x.copy()
			n.reduce_motion = v
			return n))
	host._add_toggle(list, "large_text", "ic_text", Strings.t("settings_large_text"), "", s.large_text, func(v: bool) -> void:
		App.update_settings(func(x: AppSettings) -> AppSettings:
			var n := x.copy()
			n.large_text = v
			return n))
	var space := Control.new()
	space.custom_minimum_size.y = Wg.SP_SM
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(space)
	var credits := WgButton.create(Strings.t("settings_credits"), WgButton.Kind.GHOST, "ic_info")
	credits.sound = Sound.MENU_CHANGE
	credits.activated.connect(App.open_credits)
	list.add_child(credits)
	if App.privacy_options_required:
		var privacy := WgButton.create(Strings.t("settings_privacy_options"), WgButton.Kind.GHOST)
		privacy.activated.connect(App.open_privacy_options)
		list.add_child(privacy)
	PopupHost.open(parent, card, true, host)
	# Le popup est assez haut pour montrer tous les réglages ; la liste ne défile que si l'écran est vraiment trop petit.
	host.set_scroll_region(scroll, list, PopupCard.CHROME_HEIGHT)
	card.close_pressed.connect(App.on_back)
	host.dismissed.connect(App.on_back)
	return host


static func _language_name() -> String:
	match App.settings.language:
		Language.FR:
			return Strings.t("language_fr_name")
		Language.EN:
			return Strings.t("language_en_name")
		_:
			return Strings.t("language_auto_name")


static func _section(text: String) -> Control:
	var section := Wg.label(text, 15.0, Wg.Weight.EXTRABOLD, Wg.INK_MUTED)
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var section_margin := MarginContainer.new()
	section_margin.add_theme_constant_override("margin_top", 10)
	section_margin.add_theme_constant_override("margin_bottom", 2)
	section_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section_margin.add_child(section)
	return section_margin


func _add_toggle(list: Control, key: String, icon_name: String, title: String, subtitle: String, checked: bool, on_change: Callable) -> void:
	var row := ToggleRow.create(icon_name, title, subtitle, checked, on_change)
	_rows[key] = row
	list.add_child(row)


## Met à jour les lignes sur place (un interrupteur glisse avec son rebond ; rien n'est reconstruit).
func refresh() -> void:
	var s := App.settings
	_sfx.set_value(s.sfx_volume)
	(_rows["haptics"] as ToggleRow).set_checked(s.haptics_enabled)
	(_rows["dark_mode"] as ToggleRow).set_checked(s.dark_mode)
	(_rows["reduce_motion"] as ToggleRow).set_checked(s.reduce_motion)
	(_rows["large_text"] as ToggleRow).set_checked(s.large_text)
	_music.set_value(s.music_volume)
	_language.set_value_text(_language_name())
