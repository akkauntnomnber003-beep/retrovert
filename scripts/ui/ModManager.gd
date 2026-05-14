# ModManager.gd
# In-app browser / activator / importer for .retrovert mods.
extends Control

@onready var mod_list: ItemList = $Layout/Left/ModList
@onready var icon_view: TextureRect = $Layout/Right/DetailsHeader/Icon
@onready var name_label: Label = $Layout/Right/DetailsHeader/DetailsBox/Name
@onready var version_label: Label = $Layout/Right/DetailsHeader/DetailsBox/Version
@onready var author_label: Label = $Layout/Right/DetailsHeader/DetailsBox/Author
@onready var uuid_label: Label = $Layout/Right/DetailsHeader/DetailsBox/UUID
@onready var description_label: Label = $Layout/Right/Description
@onready var tags_label: Label = $Layout/Right/Tags
@onready var enable_btn: Button = $Layout/Right/Buttons/EnableButton
@onready var export_btn: Button = $Layout/Right/Buttons/ExportButton
@onready var uninstall_btn: Button = $Layout/Right/Buttons/UninstallButton
@onready var open_folder_btn: Button = $Layout/Right/Buttons/OpenFolderButton
@onready var import_btn: Button = $TopBar/ImportButton
@onready var reload_btn: Button = $TopBar/ReloadButton
@onready var templates_btn: Button = $TopBar/TemplatesButton
@onready var back_btn: Button = $TopBar/BackButton
@onready var docs_btn: Button = $TopBar/DocsButton
@onready var file_dialog: FileDialog = $FileDialog

var _selected_uuid: String = ""
var _default_icon: Texture2D = null


func _load_default_icon() -> void:
	var path := "res://assets/sprites/items/blood_tear.png"
	if ResourceLoader.exists(path):
		_default_icon = load(path)


func _ready() -> void:
	_load_default_icon()
	mod_list.item_selected.connect(_on_mod_selected)
	enable_btn.pressed.connect(_on_toggle_enable)
	export_btn.pressed.connect(_on_export)
	uninstall_btn.pressed.connect(_on_uninstall)
	open_folder_btn.pressed.connect(_on_open_folder)
	import_btn.pressed.connect(_on_import)
	reload_btn.pressed.connect(_on_reload)
	templates_btn.pressed.connect(_on_templates)
	back_btn.pressed.connect(_on_back)
	docs_btn.pressed.connect(_on_docs)
	file_dialog.file_selected.connect(_on_file_selected)
	EventBus.mod_loaded.connect(func(_id): _refresh_list())
	EventBus.mod_unloaded.connect(func(_id): _refresh_list())
	EventBus.mods_reloaded.connect(_refresh_list)
	_apply_mcpe_style()
	_refresh_list()


func _apply_mcpe_style() -> void:
	# Minecraft PE-ish dark panel theme. Apply to all buttons.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.16, 0.12)
	sb.border_color = Color(0.45, 0.32, 0.20)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.28, 0.22, 0.14)
	sb_h.border_color = Color(0.95, 0.80, 0.45)
	var sb_p := sb.duplicate()
	sb_p.bg_color = Color(0.14, 0.10, 0.07)
	for b in [enable_btn, export_btn, uninstall_btn, open_folder_btn,
			import_btn, reload_btn, templates_btn, back_btn, docs_btn]:
		if b == null: continue
		b.add_theme_stylebox_override("normal", sb.duplicate())
		b.add_theme_stylebox_override("hover", sb_h.duplicate())
		b.add_theme_stylebox_override("pressed", sb_p.duplicate())
		b.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))


func _refresh_list() -> void:
	mod_list.clear()
	for info in ModLoader.list_installed():
		var prefix: String = "[ON] " if info.enabled else "[OFF] "
		var idx: int = mod_list.add_item(prefix + info.name)
		mod_list.set_item_metadata(idx, info.uuid)
		var icon: Texture2D = _load_mod_icon(info)
		if icon != null:
			mod_list.set_item_icon(idx, icon)
	if _selected_uuid != "" and ModLoader.get_info(_selected_uuid):
		_show_details(_selected_uuid)


func _load_mod_icon(info) -> Texture2D:
	if info == null:
		return _default_icon
	if info.icon_path != "" and FileAccess.file_exists(info.icon_path):
		var img := Image.new()
		var err := img.load(ProjectSettings.globalize_path(info.icon_path))
		if err == OK:
			return ImageTexture.create_from_image(img)
	return _default_icon


func _on_mod_selected(idx: int) -> void:
	_selected_uuid = String(mod_list.get_item_metadata(idx))
	_show_details(_selected_uuid)


func _show_details(uuid: String) -> void:
	var info = ModLoader.get_info(uuid)
	if info == null:
		return
	icon_view.texture = _load_mod_icon(info)
	name_label.text = info.name
	version_label.text = "Версия: " + info.version
	author_label.text = "Автор: " + (info.author if info.author != "" else "—")
	uuid_label.text = "UUID: " + info.uuid
	description_label.text = info.description if info.description != "" else "(нет описания)"
	tags_label.text = ("Теги: " + ", ".join(info.tags)) if not info.tags.is_empty() else ""
	enable_btn.text = "Отключить" if info.enabled else "Включить"


func _on_toggle_enable() -> void:
	if _selected_uuid == "":
		return
	var info = ModLoader.get_info(_selected_uuid)
	if info == null:
		return
	if info.enabled:
		ModLoader.deactivate(_selected_uuid)
	else:
		ModLoader.activate(_selected_uuid)
	_refresh_list()


func _on_export() -> void:
	if _selected_uuid == "":
		return
	var info = ModLoader.get_info(_selected_uuid)
	if info == null:
		return
	var path: String = "user://exported_%s.retrovert" % info.id
	if ModLoader.export_mod(_selected_uuid, path):
		_show_toast("Экспортирован: " + path)


func _on_uninstall() -> void:
	if _selected_uuid == "":
		return
	ModLoader.uninstall(_selected_uuid)
	_selected_uuid = ""
	_refresh_list()


func _on_open_folder() -> void:
	if _selected_uuid == "":
		return
	var info = ModLoader.get_info(_selected_uuid)
	if info == null:
		return
	OS.shell_open(ProjectSettings.globalize_path(info.installed_path))


func _on_import() -> void:
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var info = ModLoader.import_mod_from_file(path)
	if info:
		_show_toast("Установлен: " + info.name)
		_refresh_list()


func _on_reload() -> void:
	ModLoader.reload_all()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_docs() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModDocs.tscn")


func _on_templates() -> void:
	# Spawn a small popup listing built-in mod templates.
	var menu := PopupMenu.new()
	menu.add_item("Шаблон: Предмет", 0)
	menu.add_item("Шаблон: Враг + чат", 1)
	menu.add_item("Шаблон: События", 2)
	menu.add_item("Шаблон: Чат-ИИ", 3)
	menu.add_item("Шаблон: Чит-фрагменты", 4)
	add_child(menu)
	menu.position = templates_btn.get_screen_position() + Vector2(0, templates_btn.size.y)
	menu.popup()
	menu.id_pressed.connect(_install_template)


func _install_template(id: int) -> void:
	var template_map := {
		0: "item_template.retrovert",
		1: "enemy_template.retrovert",
		2: "event_template.retrovert",
		3: "chat_template.retrovert",
		4: "cheat_fragments.retrovert",
	}
	var fname: String = template_map.get(id, "")
	if fname == "":
		return
	var src: String = "res://mods/templates/" + fname
	if not ResourceLoader.exists(src):
		# Try direct file access (since .retrovert isn't a Godot resource).
		var abs := ProjectSettings.globalize_path(src)
		if not FileAccess.file_exists(abs):
			_show_toast("Шаблон не найден: " + fname)
			return
	# Copy resource file to a writable location, then import.
	var copy_dest: String = "user://_template_install_%d.retrovert" % Time.get_ticks_msec()
	var ok := _copy_resource_to(src, copy_dest)
	if not ok:
		_show_toast("Не удалось скопировать шаблон")
		return
	var info = ModLoader.import_mod_from_file(copy_dest)
	if info:
		_show_toast("Установлен шаблон: " + info.name)
		_refresh_list()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy_dest))


func _copy_resource_to(src: String, dst: String) -> bool:
	var src_abs := ProjectSettings.globalize_path(src)
	var dst_abs := ProjectSettings.globalize_path(dst)
	if not FileAccess.file_exists(src_abs):
		return false
	var src_f := FileAccess.open(src_abs, FileAccess.READ)
	if src_f == null:
		return false
	var bytes := src_f.get_buffer(src_f.get_length())
	src_f.close()
	var dst_f := FileAccess.open(dst_abs, FileAccess.WRITE)
	if dst_f == null:
		return false
	dst_f.store_buffer(bytes)
	dst_f.close()
	return true


func _show_toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(20, size.y - 80)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	add_child(l)
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(l.queue_free)
