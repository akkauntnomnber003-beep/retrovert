# ModManager.gd
# In-app browser / activator / importer for .retrovert mods.
extends Control

@onready var mod_list: ItemList = $Layout/Left/ModList
@onready var details_box: VBoxContainer = $Layout/Right/DetailsBox
@onready var name_label: Label = $Layout/Right/DetailsBox/Name
@onready var version_label: Label = $Layout/Right/DetailsBox/Version
@onready var author_label: Label = $Layout/Right/DetailsBox/Author
@onready var uuid_label: Label = $Layout/Right/DetailsBox/UUID
@onready var description_label: Label = $Layout/Right/DetailsBox/Description
@onready var enable_btn: Button = $Layout/Right/Buttons/EnableButton
@onready var export_btn: Button = $Layout/Right/Buttons/ExportButton
@onready var uninstall_btn: Button = $Layout/Right/Buttons/UninstallButton
@onready var import_btn: Button = $TopBar/ImportButton
@onready var reload_btn: Button = $TopBar/ReloadButton
@onready var back_btn: Button = $TopBar/BackButton
@onready var docs_btn: Button = $TopBar/DocsButton
@onready var file_dialog: FileDialog = $FileDialog

var _selected_uuid: String = ""


func _ready() -> void:
	mod_list.item_selected.connect(_on_mod_selected)
	enable_btn.pressed.connect(_on_toggle_enable)
	export_btn.pressed.connect(_on_export)
	uninstall_btn.pressed.connect(_on_uninstall)
	import_btn.pressed.connect(_on_import)
	reload_btn.pressed.connect(_on_reload)
	back_btn.pressed.connect(_on_back)
	docs_btn.pressed.connect(_on_docs)
	file_dialog.file_selected.connect(_on_file_selected)
	EventBus.mod_loaded.connect(func(_id): _refresh_list())
	EventBus.mod_unloaded.connect(func(_id): _refresh_list())
	EventBus.mods_reloaded.connect(_refresh_list)
	_refresh_list()


func _refresh_list() -> void:
	mod_list.clear()
	for info in ModLoader.list_installed():
		var prefix: String = "[ON] " if info.enabled else "[OFF] "
		mod_list.add_item(prefix + info.name)
		mod_list.set_item_metadata(mod_list.item_count - 1, info.uuid)
	if _selected_uuid != "" and ModLoader.get_info(_selected_uuid):
		_show_details(_selected_uuid)


func _on_mod_selected(idx: int) -> void:
	_selected_uuid = String(mod_list.get_item_metadata(idx))
	_show_details(_selected_uuid)


func _show_details(uuid: String) -> void:
	var info = ModLoader.get_info(uuid)
	if info == null:
		return
	name_label.text = info.name
	version_label.text = "Версия: " + info.version
	author_label.text = "Автор: " + info.author
	uuid_label.text = "UUID: " + info.uuid
	description_label.text = info.description
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


func _show_toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(20, size.y - 80)
	add_child(l)
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(l.queue_free)
