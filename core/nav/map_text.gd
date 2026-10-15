class_name MapText
extends RefCounted
## Maps as plain text, one character per cell, so a map diff reads like a picture:
##   maps/<map id>/terrain.txt
## Lines starting with ';' are comments. Every row must have the same length.

const LEGEND := {
	".": &"t_grass",
	",": &"t_field",
	"f": &"t_forest",
	"F": &"t_old_forest",
	"b": &"t_bog",
	"B": &"t_quagmire",
	"=": &"t_ford",
	"~": &"t_water",
	"i": &"t_ice",
	"#": &"t_road",
	"h": &"t_hill",
	"s": &"t_sand",
	"a": &"t_ash",
}


static func path_for(map_id: String) -> String:
	if map_id.begins_with("res://"):
		return map_id
	return "res://maps/%s/terrain.txt" % map_id


static func load_map(map_id: String, db: CatalogDB) -> NavGrid:
	var path := path_for(map_id)
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("cannot read map %s" % path)
		return null
	return parse(text, db)


## Builds a grid from map text; null (with an error) on a malformed map.
static func parse(text: String, db: CatalogDB) -> NavGrid:
	var rows := PackedStringArray()
	for line in text.split("\n"):
		var row := line.strip_edges()
		if row.is_empty() or row.begins_with(";"):
			continue
		rows.append(row)
	if rows.is_empty():
		push_error("map has no rows")
		return null
	var w := rows[0].length()
	var grid := NavGrid.for_catalog(w, rows.size(), db)
	for y in rows.size():
		if rows[y].length() != w:
			push_error("map row %d has %d cells, expected %d" % [y, rows[y].length(), w])
			return null
		for x in w:
			var ch := rows[y][x]
			if not LEGEND.has(ch):
				push_error("map row %d: unknown cell '%s'" % [y, ch])
				return null
			var tid: StringName = LEGEND[ch]
			var index := grid.terrain_index(tid)
			if index < 0:
				# A grid without the catalog knows only grass; map every tile onto it.
				index = 0
			grid.terrain[grid.cell_at(x, y)] = index
	grid.version += 1
	return grid


## The character for each cell, the inverse of parse(), for tools and tests.
static func to_text(grid: NavGrid) -> String:
	var by_id := {}
	for ch: String in LEGEND:
		var tid: StringName = LEGEND[ch]
		by_id[String(tid)] = ch
	var lines := PackedStringArray()
	for y in grid.height:
		var row := ""
		for x in grid.width:
			var ch: String = by_id.get(String(grid.terrain_at(grid.cell_at(x, y))), ".")
			row += ch
		lines.append(row)
	return "\n".join(lines) + "\n"
