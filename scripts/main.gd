extends Node2D

const CELL := 32
const MAP_ORIGIN := Vector2(20, 132)
const DEFAULT_WIDTH := 32
const DEFAULT_HEIGHT := 20
const BUILDING_COLORS := {
	"hq": Color("d9bd78"), "residential": Color("73af80"),
	"industrial": Color("bd805e"), "civic": Color("d9bd78"), "power": Color("7191bd"),
	"barracks": Color("8195c7"), "turret": Color("c77e78")
}
const COSTS := {
	"road": {"cash": 10, "steel": 0}, "residential": {"cash": 80, "steel": 0},
	"industrial": {"cash": 150, "steel": 40}, "power": {"cash": 180, "steel": 60},
	"barracks": {"cash": 220, "steel": 90}, "turret": {"cash": 160, "steel": 60}
}
const BUILDING_NAMES := {
	"hq": "Headquarters", "residential": "Homes", "industrial": "Factory", "civic": "Civic",
	"power": "Power Plant", "barracks": "Barracks", "turret": "Turret"
}

var map_width := DEFAULT_WIDTH
var map_height := DEFAULT_HEIGHT
var roads: Dictionary = {}
var buildings: Dictionary = {}
var units: Array[Dictionary] = []
var mode := "build"
var selected_tool := "residential"
var selected_unit_id := -1
var resources := {"cash": 900.0, "steel": 120.0, "population": 35, "city_hp": 100.0}
var city_id := "cityfront-demo"
var city_name := "New City"
var tick_accumulator := 0.0
var barracks_accumulator := 0.0
var wave_accumulator := 0.0
var wave := 0
var game_over := false
var message := "Build a power plant and factory to start production."
var rng := RandomNumberGenerator.new()
var file_dialog: FileDialog
var status_label: Label
var resource_label: Label
var mode_button: Button
var buttons: Dictionary = {}
var unit_id_counter := 1


func _ready() -> void:
	rng.randomize()
	city_id = "cityfront-%d" % int(Time.get_unix_time_from_system())
	_build_ui()
	_add_building(Vector2i(7, 8), "hq", false)
	_add_building(Vector2i(8, 8), "residential", false)
	roads[_key(Vector2i(9, 8))] = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		return
	tick_accumulator += delta
	barracks_accumulator += delta
	wave_accumulator += delta
	if tick_accumulator >= 1.0:
		tick_accumulator -= 1.0
		_economy_tick()
	if barracks_accumulator >= 8.0:
		_production_tick()
	if wave_accumulator >= 45.0 and wave < 5:
		_start_wave()
	_update_units(delta)
	_update_turrets(delta)
	if wave >= 5 and _count_team("enemy") == 0:
		message = "City defended. Five waves repelled."
		game_over = true
	_refresh_hud()
	queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(MAP_ORIGIN, Vector2(map_width * CELL, map_height * CELL))
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("111a1d"), true)
	for y in range(map_height):
		for x in range(map_width):
			var tile := Vector2i(x, y)
			var rect := Rect2(MAP_ORIGIN + Vector2(x * CELL, y * CELL), Vector2(CELL, CELL))
			var base_color := Color("283a3b") if (x + y) % 2 == 0 else Color("253638")
			draw_rect(rect, base_color, true)
			draw_rect(rect, Color("405454"), false, 1.0)
			var key := _key(tile)
			if roads.has(key):
				draw_rect(rect.grow(-4), Color("737f82"), true)
				draw_line(rect.position + Vector2(7, CELL / 2), rect.position + Vector2(CELL - 7, CELL / 2), Color("d6d0a5"), 2.0)
			if buildings.has(key):
				_draw_building(rect, buildings[key])
	for unit in units:
		_draw_unit(unit)
	if selected_unit_id >= 0:
		var chosen := _find_unit(selected_unit_id)
		if not chosen.is_empty():
			draw_arc(chosen["position"], 15.0, 0.0, TAU, 32, Color("f4df9d"), 2.0)
	draw_rect(map_rect, Color("99b5a9"), false, 2.0)
	if mode == "battle":
		draw_string(ThemeDB.fallback_font, Vector2(24, 124), "RTS COMMAND: select a tank, then right-click to move", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f1d991"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(24, 124), "CITY BUILDER: choose a tool above and click a tile", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b7d9c7"))


func _draw_building(rect: Rect2, building: Dictionary) -> void:
	var kind: String = building.get("kind", "residential")
	var color: Color = BUILDING_COLORS.get(kind, Color.WHITE)
	var inset := rect.grow(-5)
	draw_rect(inset, color, true)
	draw_rect(inset, Color("162326"), false, 2.0)
	var letter := kind.substr(0, 1).to_upper()
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(11, 21), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("182427"))
	if building.get("hp", 100.0) < 100.0:
		var ratio: float = clampf(float(building["hp"]) / 100.0, 0.0, 1.0)
		draw_rect(Rect2(rect.position + Vector2(3, CELL - 5), Vector2((CELL - 6) * ratio, 3)), Color("e17a6e"), true)


func _draw_unit(unit: Dictionary) -> void:
	var position: Vector2 = unit["position"]
	var color := Color("73d09a") if unit["team"] == "blue" else Color("e47768")
	draw_circle(position, 10.0, color)
	draw_arc(position, 10.0, 0.0, TAU, 24, Color("111a1d"), 2.0)
	draw_line(position, position + Vector2(11, 0), Color("182327"), 4.0)
	var hp_ratio: float = clampf(float(unit["hp"]) / float(unit["max_hp"]), 0.0, 1.0)
	draw_rect(Rect2(position + Vector2(-11, -16), Vector2(22, 3)), Color("5b2828"), true)
	draw_rect(Rect2(position + Vector2(-11, -16), Vector2(22 * hp_ratio, 3)), Color("8ed39e"), true)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 112)
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var top := HBoxContainer.new()
	rows.add_child(top)
	mode_button = _button("RTS Mode", func(): _toggle_mode())
	top.add_child(mode_button)
	top.add_child(_button("Save City", func(): _open_file_dialog(true)))
	top.add_child(_button("Load City", func(): _open_file_dialog(false)))
	top.add_child(_button("Start Raid", func(): _start_wave()))
	resource_label = Label.new()
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(resource_label)
	var tools_row := HBoxContainer.new()
	rows.add_child(tools_row)
	for kind in ["road", "residential", "industrial", "power", "barracks", "turret", "bulldoze"]:
		var tool_name := BUILDING_NAMES.get(kind, "Road" if kind == "road" else "Bulldoze")
		var button := _button(tool_name, _select_tool.bind(kind))
		button.toggle_mode = true
		button.custom_minimum_size.x = 105
		buttons[kind] = button
		tools_row.add_child(button)
	buttons["residential"].button_pressed = true
	status_label = Label.new()
	status_label.text = message
	status_label.clip_text = true
	rows.add_child(status_label)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.json", "City layout JSON")
	file_dialog.file_selected.connect(_on_file_selected)
	layer.add_child(file_dialog)
	_refresh_hud()


func _button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	return button


func _toggle_mode() -> void:
	mode = "battle" if mode == "build" else "build"
	mode_button.text = "City Builder" if mode == "battle" else "RTS Mode"
	message = "Select a friendly tank and right-click to move it." if mode == "battle" else "Build up the city and prepare for the next raid."
	_refresh_hud()
	queue_redraw()


func _select_tool(kind: String) -> void:
	selected_tool = kind
	for tool_kind in buttons.keys():
		buttons[tool_kind].button_pressed = tool_kind == kind
	message = "Selected: %s" % (BUILDING_NAMES.get(kind, "Bulldoze"))
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell := _mouse_to_cell(event.position)
		if not _inside_map(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if mode == "build":
				_place(cell, selected_tool)
			else:
				_select_unit(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if mode == "build":
				_bulldoze(cell)
			else:
				_order_selected(cell)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_map := {KEY_R: "road", KEY_1: "residential", KEY_2: "industrial", KEY_3: "power", KEY_4: "barracks", KEY_5: "turret", KEY_X: "bulldoze"}
		if key_map.has(event.keycode):
			_select_tool(key_map[event.keycode])
		elif event.keycode == KEY_TAB:
			_toggle_mode()
		elif event.keycode == KEY_SPACE:
			_spawn_friendly()


func _place(cell: Vector2i, kind: String) -> void:
	if kind == "bulldoze":
		_bulldoze(cell)
		return
	if kind == "road":
		var road_cost: Dictionary = COSTS["road"]
		if float(resources["cash"]) < road_cost["cash"]:
			message = "Not enough cash for a road."
		else:
			resources["cash"] = float(resources["cash"]) - road_cost["cash"]
			roads[_key(cell)] = true
			message = "Road placed."
		_refresh_hud()
		return
	if buildings.has(_key(cell)):
		message = "That tile already has a building."
		_refresh_hud()
		return
	var cost: Dictionary = COSTS.get(kind, {})
	if cost.is_empty():
		return
	if float(resources["cash"]) < cost["cash"] or float(resources["steel"]) < cost["steel"]:
		message = "Insufficient cash or steel for %s." % BUILDING_NAMES.get(kind, kind)
		_refresh_hud()
		return
	resources["cash"] = float(resources["cash"]) - cost["cash"]
	resources["steel"] = float(resources["steel"]) - cost["steel"]
	_add_building(cell, kind, true)


func _add_building(cell: Vector2i, kind: String, show_message: bool) -> void:
	buildings[_key(cell)] = {"x": cell.x, "y": cell.y, "kind": kind, "hp": 100.0, "owner": "player"}
	if show_message:
		message = "%s built." % BUILDING_NAMES.get(kind, kind)
	_refresh_hud()
	queue_redraw()


func _bulldoze(cell: Vector2i) -> void:
	var key := _key(cell)
	var changed := roads.erase(key)
	changed = buildings.erase(key) or changed
	message = "Tile cleared." if changed else "Nothing to demolish here."
	_refresh_hud()
	queue_redraw()


func _economy_tick() -> void:
	var houses := _count_buildings("residential")
	var plants := _count_buildings("power")
	var factories := _count_buildings("industrial")
	var barracks := _count_buildings("barracks")
	var turrets := _count_buildings("turret")
	var power_supply := plants * 12
	var power_demand := factories * 3 + barracks * 2 + turrets
	var powered := power_supply >= power_demand
	var capacity := 35 + houses * 12
	if houses > 0 and int(resources["population"]) < capacity and int(Time.get_ticks_msec() / 1000) % 8 == 0:
		resources["population"] = int(resources["population"]) + 1
	var population := int(resources["population"])
	resources["cash"] = float(resources["cash"]) + population * 0.4 - plants * 2.0 - factories * 1.0 - barracks * 1.0 - turrets * 0.5
	if powered and factories > 0 and population >= 10:
		resources["steel"] = float(resources["steel"]) + factories * 2.0
	if not powered and power_demand > 0:
		message = "Power shortfall: build another power plant."
	_refresh_hud()


func _production_tick() -> void:
	if _count_buildings("barracks") == 0 or barracks_accumulator < 8.0:
		return
	var supply := _count_buildings("power") * 12
	var demand := _count_buildings("industrial") * 3 + _count_buildings("barracks") * 2 + _count_buildings("turret")
	if supply < demand:
		barracks_accumulator = 7.0
		return
	if float(resources["cash"]) >= 90.0 and float(resources["steel"]) >= 55.0 and int(resources["population"]) >= 3:
		resources["cash"] = float(resources["cash"]) - 90.0
		resources["steel"] = float(resources["steel"]) - 55.0
		resources["population"] = int(resources["population"]) - 3
		var barracks_key: String = _first_building("barracks")
		var pos := _key_to_cell(barracks_key)
		_spawn_unit("blue", _cell_center(pos), 60.0, 58.0, 115.0, 13.0)
		barracks_accumulator = 0.0
		message = "Tank produced."
		_refresh_hud()
	else:
		barracks_accumulator = 7.0


func _start_wave() -> void:
	if wave >= 5 or game_over:
		return
	wave += 1
	wave_accumulator = 0.0
	var count := 3 + wave * 2
	for i in range(count):
		var spawn: Vector2
		if rng.randi_range(0, 1) == 0:
			spawn = Vector2(MAP_ORIGIN.x + map_width * CELL + 24, MAP_ORIGIN.y + rng.randi_range(1, map_height - 2) * CELL)
		else:
			spawn = Vector2(MAP_ORIGIN.x + rng.randi_range(int(map_width / 2), map_width - 2) * CELL, MAP_ORIGIN.y + map_height * CELL + 24)
		_spawn_unit("enemy", spawn, 45.0, 42.0, 70.0, 8.0)
	message = "Raid wave %d of 5 incoming (%d attackers)." % [wave, count]
	_refresh_hud()


func _spawn_unit(team: String, position: Vector2, hp: float, speed: float, attack_range: float, damage: float) -> void:
	units.append({"id": unit_id_counter, "team": team, "position": position, "hp": hp, "max_hp": hp, "speed": speed, "range": attack_range, "damage": damage, "cooldown": 0.0, "order": Vector2.ZERO})
	unit_id_counter += 1
	queue_redraw()


func _spawn_friendly() -> void:
	var barracks_key := _first_building("barracks")
	if barracks_key == "":
		message = "Build barracks before spawning a tank."
	elif float(resources["cash"]) < 90 or float(resources["steel"]) < 55 or int(resources["population"]) < 3:
		message = "Tank requires $90, 55 steel and 3 population."
	else:
		resources["cash"] = float(resources["cash"]) - 90.0
		resources["steel"] = float(resources["steel"]) - 55.0
		resources["population"] = int(resources["population"]) - 3
		_spawn_unit("blue", _cell_center(_key_to_cell(barracks_key)), 60.0, 58.0, 115.0, 13.0)
		message = "Tank deployed."
	_refresh_hud()


func _update_units(delta: float) -> void:
	var dead_ids: Array[int] = []
	for unit in units:
		unit["cooldown"] = maxf(0.0, float(unit["cooldown"]) - delta)
		var opponents := _opponents(unit["team"])
		var target: Dictionary = {}
		var nearest := INF
		for other in opponents:
			var distance: float = unit["position"].distance_to(other["position"])
			if distance < nearest:
				nearest = distance
				target = other
		if not target.is_empty() and nearest <= float(unit["range"]):
			if float(unit["cooldown"]) <= 0.0:
				target["hp"] = float(target["hp"]) - float(unit["damage"])
				unit["cooldown"] = 0.8
				if float(target["hp"]) <= 0.0:
					dead_ids.append(int(target["id"]))
		elif unit["team"] == "enemy":
			var hq := _hq_position()
			var direction: Vector2 = (hq - unit["position"]).normalized()
			if unit["position"].distance_to(hq) <= 26.0:
				if float(unit["cooldown"]) <= 0.0:
					resources["city_hp"] = float(resources["city_hp"]) - float(unit["damage"])
					unit["cooldown"] = 1.0
			else:
				unit["position"] += direction * float(unit["speed"]) * delta
		elif unit["team"] == "blue" and unit.get("order", Vector2.ZERO) != Vector2.ZERO:
			var order: Vector2 = unit["order"]
			var move := order - unit["position"]
			if move.length() > 8.0:
				unit["position"] += move.normalized() * float(unit["speed"]) * delta
	if not dead_ids.is_empty():
		var kept: Array[Dictionary] = []
		for unit in units:
			if not dead_ids.has(int(unit["id"])) and float(unit["hp"]) > 0.0:
				kept.append(unit)
		units = kept
	if float(resources["city_hp"]) <= 0.0:
		resources["city_hp"] = 0.0
		game_over = true
		message = "The city has fallen."


func _update_turrets(delta: float) -> void:
	for key in buildings.keys():
		var building: Dictionary = buildings[key]
		if building["kind"] != "turret":
			continue
		building["cooldown"] = maxf(0.0, float(building.get("cooldown", 0.0)) - delta)
		if float(building["cooldown"]) > 0.0:
			continue
		var turret_pos := _cell_center(Vector2i(int(building["x"]), int(building["y"])))
		var target: Dictionary = {}
		var closest := 145.0
		for unit in units:
			if unit["team"] != "enemy":
				continue
			var d: float = turret_pos.distance_to(unit["position"])
			if d < closest:
				closest = d
				target = unit
		if not target.is_empty():
			target["hp"] = float(target["hp"]) - 10.0
			building["cooldown"] = 0.7
			if float(target["hp"]) <= 0.0:
				var survivors: Array[Dictionary] = []
				for unit in units:
					if int(unit["id"]) != int(target["id"]):
						survivors.append(unit)
				units = survivors


func _select_unit(mouse_pos: Vector2) -> void:
	selected_unit_id = -1
	var closest := 22.0
	for unit in units:
		if unit["team"] != "blue":
			continue
		var distance: float = mouse_pos.distance_to(unit["position"])
		if distance < closest:
			closest = distance
			selected_unit_id = int(unit["id"])
	message = "Tank selected." if selected_unit_id >= 0 else "No friendly tank at that position."
	_refresh_hud()
	queue_redraw()


func _order_selected(cell: Vector2i) -> void:
	if selected_unit_id < 0:
		message = "Select a friendly tank first."
		_refresh_hud()
		return
	var unit := _find_unit(selected_unit_id)
	if unit.is_empty():
		return
	unit["order"] = _cell_center(cell)
	message = "Tank ordered to new position."
	_refresh_hud()


func _open_file_dialog(save: bool) -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_file = "%s-city.json" % city_name.to_lower().replace(" ", "-")
	file_dialog.popup_centered(Vector2i(760, 520))


func _on_file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_save_city(path)
	else:
		_load_city(path)


func _save_city(path: String) -> void:
	var road_data: Array[Dictionary] = []
	for key in roads.keys():
		var pos := _key_to_cell(key)
		road_data.append({"x": pos.x, "y": pos.y})
	var building_data: Array[Dictionary] = []
	for key in buildings.keys():
		building_data.append(buildings[key].duplicate(true))
	var unit_data: Array[Dictionary] = []
	for unit in units:
		unit_data.append({"id": unit["id"], "team": unit["team"], "x": unit["position"].x, "y": unit["position"].y, "hp": unit["hp"]})
	var state := {
		"schemaVersion": 2, "cityId": city_id, "name": city_name,
		"width": map_width, "height": map_height, "roads": road_data,
		"buildings": building_data, "units": unit_data,
		"resources": resources, "wave": wave
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		message = "Could not write city file: %s" % error_string(FileAccess.get_open_error())
	else:
		file.store_string(JSON.stringify(state, "\t"))
		message = "City saved: %s" % path.get_file()
	_refresh_hud()


func _load_city(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		message = "Could not open city file."
		_refresh_hud()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not [1, 2].has(int(parsed.get("schemaVersion", 0))):
		message = "Unsupported city file. Expected layout schema version 1 or 2."
		_refresh_hud()
		return
	var data: Dictionary = parsed
	map_width = clampi(int(data.get("width", DEFAULT_WIDTH)), 8, 96)
	map_height = clampi(int(data.get("height", DEFAULT_HEIGHT)), 8, 96)
	city_id = str(data.get("cityId", "cityfront-import"))
	city_name = str(data.get("name", "Imported City"))
	roads.clear()
	buildings.clear()
	units.clear()
	if int(data["schemaVersion"]) == 1:
		for tile in data.get("tiles", []):
			var pos := Vector2i(int(tile.get("x", -1)), int(tile.get("y", -1)))
			var kind := _normalize_kind(str(tile.get("kind", "")))
			if not _inside_map(pos):
				continue
			if kind == "road":
				roads[_key(pos)] = true
			elif BUILDING_COLORS.has(kind):
				_add_building(pos, kind, false)
	else:
		for road in data.get("roads", []):
			var road_pos := Vector2i(int(road.get("x", -1)), int(road.get("y", -1)))
			if _inside_map(road_pos):
				roads[_key(road_pos)] = true
		for building in data.get("buildings", []):
			var bpos := Vector2i(int(building.get("x", -1)), int(building.get("y", -1)))
			var bkind := str(building.get("kind", ""))
			if _inside_map(bpos) and BUILDING_COLORS.has(bkind):
				buildings[_key(bpos)] = building
		resources = data.get("resources", {"cash": 900.0, "steel": 120.0, "population": 35, "city_hp": 100.0})
		wave = int(data.get("wave", 0))
		for unit_data in data.get("units", []):
			var team := str(unit_data.get("team", "blue"))
			var hp := float(unit_data.get("hp", 45.0))
			_spawn_unit(team, Vector2(float(unit_data.get("x", 0)), float(unit_data.get("y", 0))), hp, 58.0 if team == "blue" else 42.0, 115.0 if team == "blue" else 70.0, 13.0 if team == "blue" else 8.0)
	message = "Loaded city layout: %s" % city_name
	_refresh_hud()
	queue_redraw()


func _refresh_hud() -> void:
	if is_instance_valid(resource_label):
		resource_label.text = "Cash $%d   Steel %d   Population %d   Power %d/%d   City HP %d   Wave %d/5" % [int(resources["cash"]), int(resources["steel"]), int(resources["population"]), _count_buildings("power") * 12, _count_buildings("industrial") * 3 + _count_buildings("barracks") * 2 + _count_buildings("turret"), int(resources["city_hp"]), wave]
	if is_instance_valid(status_label):
		status_label.text = message


func _mouse_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - MAP_ORIGIN.x) / CELL), floori((point.y - MAP_ORIGIN.y) / CELL))


func _inside_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_width and cell.y < map_height


func _cell_center(cell: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(cell.x * CELL + CELL / 2, cell.y * CELL + CELL / 2)


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _key_to_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func _normalize_kind(kind: String) -> String:
	if kind == "house":
		return "residential"
	return kind


func _count_buildings(kind: String) -> int:
	var count := 0
	for building in buildings.values():
		if building["kind"] == kind:
			count += 1
	return count


func _first_building(kind: String) -> String:
	for key in buildings.keys():
		if buildings[key]["kind"] == kind:
			return key
	return ""


func _hq_position() -> Vector2:
	var key := _first_building("hq")
	return _cell_center(_key_to_cell(key)) if key != "" else _cell_center(Vector2i(7, 8))


func _count_team(team: String) -> int:
	var count := 0
	for unit in units:
		if unit["team"] == team:
			count += 1
	return count


func _opponents(team: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var other_team := "enemy" if team == "blue" else "blue"
	for unit in units:
		if unit["team"] == other_team:
			result.append(unit)
	return result


func _find_unit(id: int) -> Dictionary:
	for unit in units:
		if int(unit["id"]) == id:
			return unit
	return {}
