# ModBundles.gd
# On first launch, copy every bundled mod archive from
# `res://mods/bundled/*.retrovert` into the user-writable
# `user://mods/<uuid>/` slot so they are immediately discoverable by
# ModLoader. After that, the user is the owner of those folders and may
# toggle, edit, or delete them at will.
extends Node

const BUNDLED_DIR := "res://mods/bundled"
const MARKER_PATH := "user://mods/.bundled_imported.v1"


func _ready() -> void:
	# Triggered by ModLoader via `import_if_needed()` — don't auto-run
	# here so we control the order relative to ModLoader's scan.
	pass


func _import_bundled() -> void:
	if FileAccess.file_exists(MARKER_PATH):
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://mods"))
	var dir := DirAccess.open(BUNDLED_DIR)
	if dir == null:
		_write_marker()
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var imported: Array = []
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".retrovert"):
			var src: String = BUNDLED_DIR.path_join(name)
			var info = ModLoader.import_mod_from_file(src)
			if info != null:
				imported.append(info.name)
		name = dir.get_next()
	dir.list_dir_end()
	_write_marker()
	if imported.size() > 0:
		ChatOverlay.log("Установлены встроенные моды: %s" %
			", ".join(imported), "ModBundles", "system")
		# Re-activate so the freshly extracted mods run their scripts.
		if ModLoader.has_method("_activate_all_enabled"):
			ModLoader._activate_all_enabled()


func _write_marker() -> void:
	var f := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("imported at %d" % Time.get_unix_time_from_system())
		f.close()


func import_if_needed() -> void:
	_import_bundled()


func reimport_bundled() -> void:
	# Force re-import (e.g. from the mod manager "reset" button).
	if FileAccess.file_exists(MARKER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER_PATH))
	_import_bundled()
