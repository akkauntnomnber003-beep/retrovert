# Headless validation: every .gd file in the project parses cleanly.
extends SceneTree


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://scripts", paths)
	_collect("res://tools", paths)
	var fail := 0
	for p in paths:
		var s: Resource = ResourceLoader.load(p)
		if s == null:
			push_error("FAIL load: %s" % p)
			fail += 1
			continue
		print("OK   %s" % p)
	if fail > 0:
		push_error("%d script(s) failed to load." % fail)
	else:
		print("All %d scripts parsed OK." % paths.size())
	quit(0 if fail == 0 else 1)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n != "." and n != "..":
			var full: String = dir_path.path_join(n)
			if d.current_is_dir():
				_collect(full, out)
			elif n.ends_with(".gd"):
				out.append(full)
		n = d.get_next()
	d.list_dir_end()
