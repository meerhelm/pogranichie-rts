class_name MapText
extends RefCounted
## Maps as plain text, one character per cell, so a map diff reads like a picture:
##   maps/<map id>/terrain.txt
## Lines starting with ';' are comments. Every row must have the same length.
## A line `@place <kind> <x> <y>` marks a place of power (M7): a PowerPlaceDef id and the
## top-left cell of its site (MagicSystem.SITE cells square, where the shrine stands).

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
## Cells with a map object: the character gives the terrain under it and the object
## (NavGrid.OBJECT_IDS): a bog ore deposit lies in a bog, a silver mine on a hill, a salt
## spring on grass.
const OBJECTS := {
	"o": [&"t_bog", &"o_bog_ore"],
	"$": [&"t_hill", &"o_silver_mine"],
	"%": [&"t_grass", &"o_salt_spring"],
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
	var places := PackedStringArray()
	for line in text.split("\n"):
		var row := line.strip_edges()
		if row.is_empty() or row.begins_with(";"):
			continue
		if row.begins_with("@place "):
			places.append(row)
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
			var tid: StringName
			if OBJECTS.has(ch):
				var obj: Array = OBJECTS[ch]
				tid = obj[0]
				grid.objects[grid.cell_at(x, y)] = NavGrid.OBJECT_IDS.find(obj[1])
			elif LEGEND.has(ch):
				tid = LEGEND[ch]
			else:
				push_error("map row %d: unknown cell '%s'" % [y, ch])
				return null
			var index := grid.terrain_index(tid)
			if index < 0:
				# A grid without the catalog knows only grass; map every tile onto it.
				index = 0
			grid.terrain[grid.cell_at(x, y)] = index
	for line in places:
		var parts := line.split(" ", false)
		if parts.size() != 4 or not parts[2].is_valid_int() or not parts[3].is_valid_int():
			push_error("map: bad place line '%s'" % line)
			return null
		var px := parts[2].to_int()
		var py := parts[3].to_int()
		if not grid.in_bounds(px, py):
			push_error("map: place '%s' is off the map" % line)
			return null
		grid.place_kinds.append(StringName(parts[1]))
		grid.place_cells.append(grid.cell_at(px, py))
	grid.version += 1
	return grid


## The character for each cell, the inverse of parse(), for tools and tests.
static func to_text(grid: NavGrid) -> String:
	var by_id := {}
	for ch: String in LEGEND:
		var tid: StringName = LEGEND[ch]
		by_id[String(tid)] = ch
	var by_object := {}
	for ch: String in OBJECTS:
		var obj: Array = OBJECTS[ch]
		by_object[String(obj[1])] = ch
	var lines := PackedStringArray()
	for y in grid.height:
		var row := ""
		for x in grid.width:
			var cell := grid.cell_at(x, y)
			var ch: String = by_id.get(String(grid.terrain_at(cell)), ".")
			if grid.objects[cell] != NavGrid.NO_OBJECT:
				ch = by_object[String(grid.object_at(cell))]
			row += ch
		lines.append(row)
	for i in grid.place_kinds.size():
		var cell := grid.place_cells[i]
		lines.append(
			"@place %s %d %d" % [grid.place_kinds[i], cell % grid.width, cell / grid.width]
		)
	return "\n".join(lines) + "\n"
