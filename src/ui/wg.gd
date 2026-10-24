class_name Wg
extends RefCounted
## Jetons du système de design (voir docs/DESIGN_SYSTEM.md). Palette vive sur fond blanc ; chaque couleur
## d'action a sa « lèvre » (variante foncée) qui donne le relief 3D des boutons bulles.
## Toutes les dimensions sont en « dp » : 1 unité de la fenêtre de référence 360 × 800.

const WHITE := Color8(0xFF, 0xFF, 0xFF)
## Encre fixe (jamais inversée) : texte posé sur une couleur vive claire (jaune), identique en mode clair et sombre.
const INK_FIXED := Color8(0x2A, 0x27, 0x50)

# --- Neutres : variables, car le mode sombre les remplace (voir `apply_theme`). L'interface est reconstruite après un
# changement de thème : aucune couleur n'est mise en cache ailleurs que dans les nœuds.
## Fond des écrans.
static var BACKGROUND := Color8(0xFF, 0xFF, 0xFF)
## Face des cartes, popups, pastilles et anneaux des boutons (blanc en clair).
static var SURFACE := Color8(0xFF, 0xFF, 0xFF)
static var INK := Color8(0x2A, 0x27, 0x50)
static var INK_MUTED := Color8(0x7B, 0x79, 0xA6)
static var OUTLINE := Color8(0xE4, 0xE1, 0xF7)
static var TRACK := Color8(0xE9, 0xE6, 0xFA)
## Fond de la grille de jeu : une grande bulle plate, claire, sans contour.
static var GRID_BUBBLE := Color8(0xEF, 0xEC, 0xFF)
static var LOCKED := Color8(0xD9, 0xD7, 0xEF)
static var LOCKED_DARK := Color8(0xBD, 0xBA, 0xE0)
static var LOCKED_INK := Color8(0x95, 0x92, 0xC4)
static var SCRIM := Color(0x20 / 255.0, 0x1A / 255.0, 0x4A / 255.0, 0.5)
## Ombre portée douce sous les cartes et les anneaux.
static var SHADOW := Color(0.16, 0.15, 0.31, 0.20)
## Filigrane du fond d'accueil.
static var WATERMARK := Color(0x7B / 255.0, 0x5C / 255.0, 0xFF / 255.0, 0.05)
const PURPLE := Color8(0x7B, 0x5C, 0xFF)
const PURPLE_DARK := Color8(0x5B, 0x3E, 0xE0)
const PURPLE_DEEP := Color8(0x3F, 0x2A, 0xB0)
const PURPLE_SOFT := Color8(0xEE, 0xE9, 0xFF)
const BLUE := Color8(0x2E, 0xB8, 0xFF)
const BLUE_DARK := Color8(0x16, 0x93, 0xDB)
const GREEN := Color8(0x5C, 0xD6, 0x2F)
const GREEN_DARK := Color8(0x38, 0xA8, 0x18)
const YELLOW := Color8(0xFF, 0xC8, 0x1E)
const YELLOW_DARK := Color8(0xF2, 0x9E, 0x00)
const YELLOW_SOFT := Color8(0xFF, 0xF4, 0xC7)
const ORANGE := Color8(0xFF, 0x8A, 0x1F)
const ORANGE_DARK := Color8(0xD9, 0x6A, 0x00)
const PINK := Color8(0xFF, 0x3D, 0x8B)
const PINK_DARK := Color8(0xC7, 0x1F, 0x68)
const RED := Color8(0xFF, 0x4B, 0x55)
const RED_DARK := Color8(0xC4, 0x2A, 0x33)
const TEAL := Color8(0x14, 0xD1, 0xB8)
const TEAL_DARK := Color8(0x0E, 0x9F, 0x8B)

const ERROR := RED

# Espacements, rayons, tailles tactiles
## Écart minimal entre un bouton et la zone sûre d'Android (barre d'état, encoche, gestes) : un bouton ne la touche jamais.
## Les écrans dont les boutons sont déjà plus loin ne changent pas (voir UiKit.edge).
const EDGE_GAP := 12.0
const SP_XS := 4.0
const SP_SM := 8.0
const SP_MD := 16.0
const SP_LG := 24.0
const SP_XL := 32.0
const R_SM := 10.0
const R_MD := 18.0
const R_LG := 28.0
const R_PILL := 999.0
## La zone cliquable reste de 48 dp même quand le bouton est visuellement plus compact (accessibilité).
const MIN_TOUCH := 48.0
const ICON_BUTTON := 38.0
const BUTTON := 46.0
const TILE := 56.0
## Épaisseur de la « lèvre » 3D sous un bouton bulle.
const LIP := 4.0

# Durées d'animation (secondes). Aucune animation de fondu : tout rebondit, grandit ou glisse.
const QUICK := 0.12
const STANDARD := 0.22
const SLOW := 0.30
## Micro-délai avant une action de navigation, pour laisser jouer l'animation de pression.
const PRESS_DELAY := 0.08

enum Weight { BOLD = 700, EXTRABOLD = 800, BLACK = 900 }

## Mode sombre actif (réglage). Modifié uniquement par `apply_theme`.
static var dark: bool = false
## Facteur d'échelle du texte (réglage « texte plus grand »).
static var text_scale: float = 1.0
## Réglage « animations réduites » : tout passe en échelon, plus aucun rebond.
static var reduce_motion: bool = false
## Vrai pendant la reconstruction d'un écran sur place (changement de langue…) : pas de nouvelle animation d'entrée.
static var suppress_intro: bool = false

static var _fonts: Dictionary = {}
static var _boxes: Dictionary = {}


## Teinte douce des tracés sur la grille : moins saturée, plus claire et translucide, pour que les lettres
## (toujours foncées) restent parfaitement lisibles par-dessus.
const TRACE_SATURATION := 0.55
const TRACE_ALPHA := 0.52

static func trace_tint(color: Color, alpha: float = TRACE_ALPHA) -> Color:
	return Color.from_hsv(color.h, color.s * TRACE_SATURATION, minf(1.0, color.v * 1.06), alpha)


## Applique le thème clair ou sombre aux neutres. À appeler avant de (re)construire l'interface.
static func apply_theme(use_dark: bool) -> void:
	dark = use_dark
	_boxes.clear()
	# Le fond derrière tous les écrans (zones non couvertes, bords de transition) suit le thème.
	RenderingServer.set_default_clear_color(Color8(0x15, 0x13, 0x2E) if use_dark else Color8(0xFF, 0xFF, 0xFF))
	if use_dark:
		BACKGROUND = Color8(0x15, 0x13, 0x2E)
		SURFACE = Color8(0x23, 0x20, 0x45)
		INK = Color8(0xF1, 0xEF, 0xFF)
		INK_MUTED = Color8(0xA9, 0xA6, 0xD6)
		OUTLINE = Color8(0x3A, 0x36, 0x68)
		TRACK = Color8(0x30, 0x2D, 0x5A)
		GRID_BUBBLE = Color8(0x2B, 0x27, 0x55)
		LOCKED = Color8(0x38, 0x35, 0x66)
		LOCKED_DARK = Color8(0x28, 0x25, 0x4D)
		LOCKED_INK = Color8(0x86, 0x83, 0xB8)
		SCRIM = Color(0.03, 0.02, 0.10, 0.66)
		SHADOW = Color(0.0, 0.0, 0.0, 0.34)
		WATERMARK = Color(0xB8 / 255.0, 0xA6 / 255.0, 0xFF / 255.0, 0.055)
	else:
		BACKGROUND = Color8(0xFF, 0xFF, 0xFF)
		SURFACE = Color8(0xFF, 0xFF, 0xFF)
		INK = Color8(0x2A, 0x27, 0x50)
		INK_MUTED = Color8(0x7B, 0x79, 0xA6)
		OUTLINE = Color8(0xE4, 0xE1, 0xF7)
		TRACK = Color8(0xE9, 0xE6, 0xFA)
		GRID_BUBBLE = Color8(0xEF, 0xEC, 0xFF)
		LOCKED = Color8(0xD9, 0xD7, 0xEF)
		LOCKED_DARK = Color8(0xBD, 0xBA, 0xE0)
		LOCKED_INK = Color8(0x95, 0x92, 0xC4)
		SCRIM = Color(0x20 / 255.0, 0x1A / 255.0, 0x4A / 255.0, 0.5)
		SHADOW = Color(0.16, 0.15, 0.31, 0.20)
		WATERMARK = Color(0x7B / 255.0, 0x5C / 255.0, 0xFF / 255.0, 0.05)


## Libère les polices et styles mis en cache (à la fermeture : aucune ressource statique résiduelle).
static func clear_caches() -> void:
	_fonts.clear()
	_boxes.clear()


## Police Roboto variable à la graisse demandée (700 / 800 / 900).
static func font(weight: int = Weight.BOLD) -> Font:
	if not _fonts.has(weight):
		var variation := FontVariation.new()
		variation.base_font = load("res://assets/fonts/Roboto-VF.ttf")
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = variation
	return _fonts[weight]


## Création d'un Label au style du design system. `shadow` : couleur de l'ombre dure (0, 3 dp) des libellés de bouton.
static func label(text: String, size: float, weight: int = Weight.BOLD, color: Color = INK, shadow: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", int(round(size * text_scale)))
	l.add_theme_color_override("font_color", color)
	if shadow.a > 0.0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_y", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Rectangle arrondi plein (StyleBoxFlat mis en cache par couleur et rayon, anticrénelé).
static func rrect(canvas: CanvasItem, rect: Rect2, color: Color, radius: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var key := Vector2(float(color.to_rgba32()), roundf(r * 4.0) / 4.0)
	var box: StyleBoxFlat = _boxes.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(ceilf(r)))
		box.corner_detail = 10
		box.anti_aliasing = true
		_boxes[key] = box
	canvas.draw_style_box(box, rect)


## Contour arrondi (sans remplissage), mis en cache.
static func outline(canvas: CanvasItem, rect: Rect2, color: Color, radius: float, width: float) -> void:
	var key := Vector3(float(color.to_rgba32()), roundf(radius * 4.0) / 4.0, width)
	var box: StyleBoxFlat = _boxes.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = color
		box.set_border_width_all(int(ceilf(width)))
		box.set_corner_radius_all(int(ceilf(radius)))
		box.anti_aliasing = true
		_boxes[key] = box
	canvas.draw_style_box(box, rect)


## Couleurs d'un style visuel de difficulté (accent, foncé, doux, texte sur accent).
static func style_palette(visual_style: int) -> Dictionary:
	match visual_style:
		VisualStyle.STYLE_1:
			return {"accent": TEAL, "dark": TEAL_DARK, "soft": Color8(0xDD, 0xFA, 0xF5), "on_accent": WHITE}
		VisualStyle.STYLE_2:
			return {"accent": YELLOW, "dark": YELLOW_DARK, "soft": YELLOW_SOFT, "on_accent": INK_FIXED}
		VisualStyle.STYLE_3:
			return {"accent": PINK, "dark": PINK_DARK, "soft": Color8(0xFF, 0xE3, 0xEF), "on_accent": WHITE}
		_:
			return {"accent": PURPLE, "dark": PURPLE_DEEP, "soft": PURPLE_SOFT, "on_accent": WHITE}


## Ambiance d'un chapitre (clé `paletteKey` des données) : couleur, foncé, ciel, illustration.
## Dix univers : meadow (nature), voyage, cosmos (espace), legend (légendes), lab (sciences), history (histoire),
## arts, arena (sports), kitchen (gastronomie), workshop (métiers). « dusk » est l'ancien nom du chapitre Voyage.
## `ribbon` : couleur du ruban de titre (voir RibbonBanner.COLORS).
static func chapter_theme(palette_key: String) -> Dictionary:
	match palette_key:
		"voyage", "dusk":
			return {"color": BLUE, "dark": BLUE_DARK, "sky": Color8(0x7A, 0xD3, 0xFF), "illustration": "ill_chapter_voyage", "ribbon": "blue"}
		"cosmos":
			return {"color": PURPLE, "dark": PURPLE_DARK, "sky": Color8(0x2D, 0x24, 0x8F), "illustration": "ill_chapter_cosmos", "ribbon": "purple"}
		"legend":
			return {"color": ORANGE, "dark": ORANGE_DARK, "sky": Color8(0xFF, 0xA9, 0x5E), "illustration": "ill_chapter_legend", "ribbon": "red"}
		"lab":
			return {"color": TEAL, "dark": TEAL_DARK, "sky": Color8(0x8F, 0xEC, 0xDD), "illustration": "ill_chapter_lab", "ribbon": "pink"}
		"history":
			return {"color": Color8(0xC9, 0x8A, 0x3C), "dark": Color8(0xA2, 0x6A, 0x22), "sky": Color8(0xF8, 0xD7, 0x8B), "illustration": "ill_chapter_history", "ribbon": "yellow"}
		"arts":
			return {"color": PINK, "dark": PINK_DARK, "sky": Color8(0xFF, 0x9C, 0xC8), "illustration": "ill_chapter_arts", "ribbon": "pink"}
		"arena":
			return {"color": Color8(0xF0, 0x5A, 0x4C), "dark": Color8(0xC9, 0x3D, 0x31), "sky": Color8(0xFF, 0x8A, 0x7A), "illustration": "ill_chapter_arena", "ribbon": "red"}
		"kitchen":
			return {"color": YELLOW, "dark": YELLOW_DARK, "sky": Color8(0xFF, 0xD8, 0x66), "illustration": "ill_chapter_kitchen", "ribbon": "yellow"}
		"workshop":
			return {"color": Color8(0x4F, 0x6D, 0xE8), "dark": Color8(0x36, 0x4F, 0xC0), "sky": Color8(0x7C, 0x93, 0xFF), "illustration": "ill_chapter_workshop", "ribbon": "blue"}
	return {"color": GREEN, "dark": GREEN_DARK, "sky": Color8(0xFF, 0xE4, 0x5C), "illustration": "ill_chapter_meadow", "ribbon": "green"}
