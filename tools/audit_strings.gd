extends SceneTree
## Audits locale/strings.csv against the project.
##   godot --headless --path . -s tools/audit_strings.gd
## Prints, then exits 1 when something is wrong:
##   MISSING   a key used in code or scenes that is not in the csv (shows raw in game)
##   EMPTY     a key with no English or no Turkish text
##   PLACEHOLDER  %s / %d count differs between English and Turkish
##   DUPLICATE a key listed twice
## Also SPACES (leading, trailing or double space).
## Prints for review (no exit code): PUNCT (final . ! ? differs between languages), SAME (en == tr), UNUSED (a key whose siblings are used but it is not;
## keys built in code as prefix + suffix are matched by suffix, whole unused groups are skipped).
## Run `godot --headless --path . --import` first so class names resolve.

const CSV := "res://locale/strings.csv"
const SKIP_DIRS := [".godot", "export", ".git", "addons", "assets", "locale"]
const EXTS := ["gd", "tscn", "tres"]

var _files: Array[String] = []


func _initialize() -> void:
	var rows := _read_csv()
	var keys: Dictionary = rows.keys
	var bad := 0

	for k: String in rows.dupes:
		print("DUPLICATE ", k)
		bad += 1
	for k: String in keys:
		var en: String = keys[k][0]
		var tr_text: String = keys[k][1]
		if en.strip_edges() == "" or tr_text.strip_edges() == "":
			print("EMPTY ", k, " en=", en != "", " tr=", tr_text != "")
			bad += 1
		for txt: String in [en, tr_text]:
			if txt != txt.strip_edges() or txt.contains("  "):
				print("SPACES ", k, " (leading, trailing or double space)")
				bad += 1
				break
		if _count_ph(en) != _count_ph(tr_text):
			print("PLACEHOLDER ", k, " en=", _count_ph(en), " tr=", _count_ph(tr_text))
			bad += 1

	var prefixes := {}
	for k: String in keys:
		prefixes[k.get_slice("_", 0)] = true
	_walk("res://")
	var used := {}
	var suffixes := {}
	var rx := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	for f in _files:
		var text := FileAccess.get_file_as_string(f)
		for m in rx.search_all(text):
			var s := m.get_string(1)
			if keys.has(s):
				used[s] = f
			else:
				suffixes[s] = f   # maybe a suffix of keys built from a prefix in code
				var found := false
				for k: String in keys:
					if k.ends_with("_" + s):
						found = true
						used[k] = f
				if not found and prefixes.has(s.get_slice("_", 0)) and not f.begins_with("res://tests/") and not f.begins_with("res://tools/"):
					print("MISSING ", s, "  (", f.trim_prefix("res://"), ")")
					bad += 1

	var same := []
	for k: String in keys:
		if keys[k][0] == keys[k][1] and keys[k][0].length() > 3:
			same.append(k)
	var punct := []
	for k: String in keys:
		var a: String = keys[k][0].strip_edges()
		var b: String = keys[k][1].strip_edges()
		if a != "" and b != "" and _end(a) != _end(b):
			punct.append(k + " [" + a.right(6) + " | " + b.right(6) + "]")
	print("PUNCT (", punct.size(), ") ends differ: ", "; ".join(punct))
	print("SAME (", same.size(), "): ", ", ".join(same))
	var group_used := {}
	for k: String in used:
		group_used[k.get_slice("_", 0)] = true
	var unused := []
	for k: String in keys:
		if not used.has(k) and group_used.has(k.get_slice("_", 0)):
			unused.append(k)
	print("UNUSED (", unused.size(), "): ", ", ".join(unused))
	print("keys: ", keys.size(), "  problems: ", bad)
	quit(1 if bad > 0 else 0)


func _read_csv() -> Dictionary:
	var f := FileAccess.open(CSV, FileAccess.READ)
	var keys := {}
	var dupes: Array[String] = []
	f.get_csv_line()  # header
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < 3 or r[0] == "":
			continue
		if keys.has(r[0]):
			dupes.append(r[0])
		keys[r[0]] = [r[1], r[2]]
	return {keys = keys, dupes = dupes}


func _end(s: String) -> String:
	var c := s.right(1)
	return c if c in [".", "!", "?", ":", "…"] else ""


func _count_ph(s: String) -> int:
	var n := 0
	var rx := RegEx.create_from_string("%[-+0-9.]*[sdif]")
	for _m in rx.search_all(s):
		n += 1
	return n


func _walk(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d in SKIP_DIRS or d.begins_with("."):
			continue
		_walk(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in EXTS:
			_files.append(dir.path_join(f))
