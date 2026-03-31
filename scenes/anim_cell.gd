extends PanelContainer
class_name AnimCell

@onready var cell_num: Label = $CellVBox/CellNum
@onready var cell_selected: CheckBox = $CellVBox/CellSelected
@onready var x_out_cell_button: Button = $CellVBox/XOutCellButton


signal cell_clicked()
signal cell_closed()

func _ready() -> void:
	cell_selected.connect("pressed", clicked)
	x_out_cell_button.connect("pressed", close_cell)

func setup(anim_num: int):
	cell_num.text = str(anim_num)

func clicked():
	cell_clicked.emit()

func close_cell():
	cell_closed.emit()
