extends Node
## Ortak 3B tok (chunky) StyleBoxFlat üreteci, buton basılma Tween animasyonları
## ve dinamik oyun temaları (Zümrüt Tapınak, Obsidyen Altın, Buzul Rünü) yöneticisi.

signal theme_changed(theme_id: String)

const THEMES: Dictionary = {
	"emerald_temple": {
		"id": "emerald_temple",
		"name": "Zümrüt Tapınak",
		"cost": 0,
		"bg_deep": Color("#091410"),
		"card_bg": Color("#11221B"),
		"card_dark": Color("#0B1612"),
		"border_gold": Color("#F59E0B"),
		"gold_light": Color("#FDE68A"),
		"border_stone": Color("#244A3B"),
		"text_main": Color("#F3EFE6"),
		"text_dim": Color("#9BB0A5"),
		"cell_a": Color("#132A21"),
		"cell_b": Color("#0F231B"),
		"cell_stroke": Color("#21483A"),
		"void_hole": Color("#060D0A"),
		"accent_secondary": Color("#34D399")
	},
	"obsidian_gold": {
		"id": "obsidian_gold",
		"name": "Obsidyen Altın",
		"cost": 450,
		"bg_deep": Color("#0E0B10"),
		"card_bg": Color("#1B1620"),
		"card_dark": Color("#120E16"),
		"border_gold": Color("#F59E0B"),
		"gold_light": Color("#FEF08A"),
		"border_stone": Color("#4A3820"),
		"text_main": Color("#F3EFE6"),
		"text_dim": Color("#B8AA96"),
		"cell_a": Color("#211A26"),
		"cell_b": Color("#1B1520"),
		"cell_stroke": Color("#463522"),
		"void_hole": Color("#070509"),
		"accent_secondary": Color("#FBBF24")
	},
	"glacier_rune": {
		"id": "glacier_rune",
		"name": "Buzul Rünü",
		"cost": 650,
		"bg_deep": Color("#07131C"),
		"card_bg": Color("#0F2230"),
		"card_dark": Color("#0A1722"),
		"border_gold": Color("#F59E0B"),
		"gold_light": Color("#FDE68A"),
		"border_stone": Color("#23506E"),
		"text_main": Color("#F3EFE6"),
		"text_dim": Color("#9AC0D6"),
		"cell_a": Color("#132C3E"),
		"cell_b": Color("#0F2434"),
		"cell_stroke": Color("#235373"),
		"void_hole": Color("#040B11"),
		"accent_secondary": Color("#38BDF8")
	}
}

const THEME_ORDER: Array = ["emerald_temple", "obsidian_gold", "glacier_rune"]


func _ready() -> void:
	RenderingServer.set_default_clear_color(get_color("bg_deep"))


func get_active_theme_id() -> String:
	var tid: String = GameState.active_theme
	if THEMES.has(tid):
		return tid
	return "emerald_temple"


func get_theme_data(theme_id: String = "") -> Dictionary:
	var use_id: String = theme_id if theme_id != "" else get_active_theme_id()
	if THEMES.has(use_id):
		return THEMES[use_id]
	return THEMES["emerald_temple"]


func get_color(key: String) -> Color:
	var td: Dictionary = get_theme_data()
	if td.has(key):
		return td[key]
	return Color("#F3EFE6")


func apply_theme(theme_id: String) -> void:
	if not THEMES.has(theme_id):
		return
	GameState.active_theme = theme_id
	GameState.save_game()
	RenderingServer.set_default_clear_color(THEMES[theme_id]["bg_deep"])
	theme_changed.emit(theme_id)


## Kalın yuvarlatılmış kenarlı, alt gölgeli (3D tok hissiyatlı) ortak kart stili üretir.
func make_card_style(
	bg_col: Color = Color(0, 0, 0, 0),
	border_col: Color = Color(0, 0, 0, 0),
	corner_radius: int = 16,
	pad_h: int = 16,
	pad_v: int = 12
) -> StyleBoxFlat:
	var td: Dictionary = get_theme_data()
	var use_bg: Color = td["card_bg"] if bg_col.a == 0.0 else bg_col
	var use_border: Color = td["border_gold"] if border_col.a == 0.0 else border_col

	var sb := StyleBoxFlat.new()
	sb.bg_color = use_bg
	sb.border_color = use_border
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 6
	sb.set_corner_radius_all(corner_radius)
	sb.shadow_color = Color(0, 0, 0, 0.42)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v + 2
	return sb


func make_card_panel(gold_border: bool = false, pad_h: int = 16, pad_v: int = 12) -> PanelContainer:
	var td: Dictionary = get_theme_data()
	var b_col: Color = td["border_gold"] if gold_border else td["border_stone"]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", make_card_style(td["card_bg"], b_col, 16, pad_h, pad_v))
	return pc


## Tok 3B görünümlü, basıldığında hafif küçülme Tween animasyonlu ortak buton üretir.
func make_button(
	text_val: String,
	font_sz: int = 20,
	variant: String = "gold",
	corner_radius: int = 14
) -> Button:
	var td: Dictionary = get_theme_data()
	var bg_col: Color = td["card_bg"]
	var border_col: Color = td["border_gold"]
	var txt_col: Color = td["text_main"]

	match variant:
		"gold":
			bg_col = td["card_bg"].lightened(0.05)
			border_col = td["border_gold"]
			txt_col = td["gold_light"]
		"stone":
			bg_col = td["card_bg"]
			border_col = td["border_stone"]
			txt_col = td["text_main"]
		"emerald":
			bg_col = Color("#143326")
			border_col = Color("#34D399")
			txt_col = td["text_main"]
		"purple":
			bg_col = Color("#211832")
			border_col = Color("#C084FC")
			txt_col = Color("#F3E8FF")
		"amber_solid":
			bg_col = Color("#362508")
			border_col = Color("#F59E0B")
			txt_col = Color("#FEF08A")
		"danger":
			bg_col = Color("#2B1418")
			border_col = Color("#F87171")
			txt_col = Color("#FEE2E2")

	var b := Button.new()
	b.text = text_val
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", font_sz)
	b.add_theme_color_override("font_color", txt_col)
	b.add_theme_color_override("font_hover_color", td["gold_light"])
	b.add_theme_color_override("font_pressed_color", td["gold_light"])
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.58, 0.65))

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = bg_col
	normal_sb.border_color = border_col
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 6
	normal_sb.set_corner_radius_all(corner_radius)
	normal_sb.shadow_color = Color(0, 0, 0, 0.40)
	normal_sb.shadow_size = 5
	normal_sb.shadow_offset = Vector2(0, 3)
	normal_sb.content_margin_left = 14
	normal_sb.content_margin_right = 14
	normal_sb.content_margin_top = 8
	normal_sb.content_margin_bottom = 11

	var hover_sb: StyleBoxFlat = normal_sb.duplicate()
	hover_sb.bg_color = bg_col.lightened(0.09)
	hover_sb.border_color = td["gold_light"]

	var pressed_sb: StyleBoxFlat = normal_sb.duplicate()
	pressed_sb.bg_color = bg_col.darkened(0.08)
	pressed_sb.border_width_bottom = 3
	pressed_sb.shadow_size = 2
	pressed_sb.shadow_offset = Vector2(0, 1)
	pressed_sb.content_margin_top = 11
	pressed_sb.content_margin_bottom = 8

	var disabled_sb: StyleBoxFlat = normal_sb.duplicate()
	disabled_sb.bg_color = td["card_dark"]
	disabled_sb.border_color = Color(0.2, 0.26, 0.24, 0.6)
	disabled_sb.border_width_bottom = 3
	disabled_sb.shadow_size = 0

	b.add_theme_stylebox_override("normal", normal_sb)
	b.add_theme_stylebox_override("hover", hover_sb)
	b.add_theme_stylebox_override("pressed", pressed_sb)
	b.add_theme_stylebox_override("disabled", disabled_sb)

	attach_press_tween(b)
	return b


func attach_press_tween(btn: Button) -> void:
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)
	btn.button_down.connect(func() -> void:
		if btn.disabled or not btn.is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func() -> void:
		if not btn.is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func make_label(
	txt: String,
	font_sz: int = 20,
	col_key_or_color: Variant = null,
	centered: bool = false
) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", font_sz)
	var use_col: Color = get_color("text_main")
	if typeof(col_key_or_color) == TYPE_COLOR:
		use_col = col_key_or_color
	elif typeof(col_key_or_color) == TYPE_STRING and str(col_key_or_color) != "":
		use_col = get_color(str(col_key_or_color))
	l.add_theme_color_override("font_color", use_col)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
