@tool
extends EditorPlugin

var dock: PanelContainer
var popup: AcceptDialog
var category_edit: LineEdit
var scene_name_edit: LineEdit
var scene_path_edit: LineEdit
var list_container: VBoxContainer

const SCENE_SHELF = preload("uid://dmh0b68qkckr0")
const SCENE_CATEGORY_PANEL = preload("uid://c2537mqjqwvv")
const SCENE_PANEL = preload("uid://nlh8hewi7iwu")


const DATA_FILE := "res://addons/scene-shelf/data/data.json"
var scene_data := {}

func _enter_tree() -> void:
	dock = SCENE_SHELF.instantiate()
	dock.name = "Scene Shelf"
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, dock)

	## --- Get references to nodes inside the dock scene ---
	list_container = dock.get_node("MarginContainer/VBoxContainer/ScrollContainer/PanelContainer/SceneList") # adjust this name to match your scene
	var add_button: Button = dock.get_node("MarginContainer/VBoxContainer/HBoxContainer/AddButton")
#
	## --- Create popup entirely in code ---
	popup = AcceptDialog.new()
	popup.title = "Add New Scene"
	popup.min_size = Vector2(380, 220)
	get_editor_interface().get_base_control().add_child(popup)

	var popup_vbox = VBoxContainer.new()
	popup.add_child(popup_vbox)

	var category_hbox = HBoxContainer.new()
	var category_label = Label.new()
	category_label.text = "Enter Category:"
	category_hbox.add_child(category_label)
	category_edit = LineEdit.new()
	category_edit.placeholder_text = "Category name..."
	category_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_hbox.add_child(category_edit)
	popup_vbox.add_child(category_hbox)

	var scene_hbox = HBoxContainer.new()
	var scene_label = Label.new()
	scene_label.text = "Enter Scene Name:"
	scene_hbox.add_child(scene_label)
	scene_name_edit = LineEdit.new()
	scene_name_edit.placeholder_text = "Scene name..."
	scene_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_hbox.add_child(scene_name_edit)
	popup_vbox.add_child(scene_hbox)

	var path_hbox = HBoxContainer.new()
	var path_label = Label.new()
	path_label.text = "Scene File Path:"
	path_hbox.add_child(path_label)
	scene_path_edit = LineEdit.new()
	scene_path_edit.placeholder_text = "res://path/to/scene.tscn"
	scene_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_hbox.add_child(scene_path_edit)
	popup_vbox.add_child(path_hbox)

	## --- Connect signals ---
	add_button.pressed.connect(_on_add_button_pressed)
	popup.confirmed.connect(_on_popup_confirmed)
	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)

	## --- Load and display data ---
	_load_data()
	_refresh_scene_list()

func _on_add_button_pressed() -> void:
	category_edit.clear()
	scene_name_edit.clear()
	scene_path_edit.clear()
	popup.popup_centered()

func _on_popup_confirmed() -> void:
	var category = category_edit.text.strip_edges()
	var scene_name = scene_name_edit.text.strip_edges()
	var scene_path = scene_path_edit.text.strip_edges()

	if scene_path == "" or scene_name == "":
		push_warning("Please enter both scene name and path.")
		return

	## --- Prevent duplicates globally ---
	for existing_category in scene_data.keys():
		for existing_scene in scene_data[existing_category]:
			if existing_scene["name"] == scene_name:
				push_warning("A scene with that name already exists.")
				return
			if existing_scene["path"] == scene_path:
				push_warning("A scene with that path already exists.")
				return

	## --- Add or create category ---
	if not scene_data.has(category):
		scene_data[category] = []

	scene_data[category].append({
		"name": scene_name,
		"path": scene_path
	})

	_save_data()
	_refresh_scene_list()


func _refresh_scene_list() -> void:
	_clear_children(list_container)

	for category in scene_data.keys():
		## --- Instantiate your Category Scene ---
		var category_panel: FoldableContainer = SCENE_CATEGORY_PANEL.instantiate()
		list_container.add_child(category_panel)

		var scene_container: VBoxContainer = category_panel.get_node("ListContainer")
		
		category_panel.title = category

		## --- Add each scene entry under this category ---
		for scene_info in scene_data[category]:
			var scene_panel = SCENE_PANEL.instantiate()
			scene_container.add_child(scene_panel)
			
			var scene_btn: Button = scene_panel.get_node("HBoxContainer/SceneButton")
			var del_btn: Button = scene_panel.get_node("HBoxContainer/DeleteSceneButton")

			scene_btn.text = scene_info["name"]
			scene_btn.tooltip_text = scene_info["path"]

			scene_btn.pressed.connect(func(): _open_scene(scene_info["path"]))
			del_btn.pressed.connect(func(): _delete_scene(category, scene_info))

func _delete_scene(category: String, scene_info: Dictionary) -> void:
	if not scene_data.has(category):
		return

	var category_list = scene_data[category]
	for i in range(category_list.size()):
		if category_list[i]["name"] == scene_info["name"] and category_list[i]["path"] == scene_info["path"]:
			category_list.remove_at(i)
			break

	if category_list.is_empty():
		scene_data.erase(category)

	_save_data()
	_refresh_scene_list()

func _open_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Scene not found: " + path)
		return
	get_editor_interface().open_scene_from_path(path)

func _save_data() -> void:
	var file = FileAccess.open(DATA_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scene_data, "\t"))
		file.close()

func _load_data() -> void:
	scene_data.clear()
	if not FileAccess.file_exists(DATA_FILE):
		return
	var file = FileAccess.open(DATA_FILE, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	if content.strip_edges() == "":
		return
	var result = JSON.parse_string(content)
	if typeof(result) == TYPE_DICTIONARY:
		scene_data = result

func _on_filesystem_changed() -> void:
	var changed := false
	for category in scene_data.keys():
		for i in range(scene_data[category].size() - 1, -1, -1):
			var scene_info = scene_data[category][i]
			if not FileAccess.file_exists(scene_info["path"]):
				scene_data[category].remove_at(i)
				changed = true
		if scene_data[category].is_empty():
			scene_data.erase(category)
	if changed:
		_save_data()
		_refresh_scene_list()

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.free()
		dock = null

func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()
