@tool
class_name FoldableSection
extends VBoxContainer

var header_button: Button
var content: VBoxContainer

var _title: String


func _init(section_title: String = "Section") -> void:
	_title = section_title

	header_button = Button.new()
	header_button.text = "▸ " + _title
	header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_button.toggle_mode = true
	header_button.flat = true
	add_child(header_button)

	content = VBoxContainer.new()
	content.visible = false
	content.add_theme_constant_override("separation", 4)
	add_child(content)

	header_button.toggled.connect(_on_toggled)


func _on_toggled(pressed: bool) -> void:
	content.visible = pressed
	header_button.text = ("▾ " if pressed else "▸ ") + _title


func add_content(node: Control) -> void:
	content.add_child(node)


func set_title(new_title: String) -> void:
	_title = new_title
	header_button.text = ("▾ " if content.visible else "▸ ") + _title
