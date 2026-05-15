# ModDocs.gd
# In-app reference for the RatScript modding language.
# The body is generated from scripts/mods/docs.gd so we can iterate
# on it without rebuilding scene files.
extends Control

@onready var category_list: ItemList = $Layout/Left/CategoryList
@onready var content_label: RichTextLabel = $Layout/Right/Content
@onready var search_field: LineEdit = $Layout/Right/SearchBar/SearchField
@onready var back_btn: Button = $TopBar/BackButton

const Docs := preload("res://scripts/mods/Docs.gd")


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	category_list.item_selected.connect(_on_category_selected)
	search_field.text_changed.connect(_on_search)
	for cat in Docs.categories():
		category_list.add_item(cat)
	if category_list.item_count > 0:
		category_list.select(0)
		_show_category(Docs.categories()[0])


func _on_category_selected(idx: int) -> void:
	_show_category(category_list.get_item_text(idx))


func _show_category(cat_name: String) -> void:
	content_label.clear()
	content_label.append_text(Docs.render_category(cat_name))


func _on_search(text: String) -> void:
	content_label.clear()
	content_label.append_text(Docs.search(text))


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
