extends ColorRect

const CELL_WIDTH = 64
const BOARD_WIDTH = CELL_WIDTH*5
const BOARD_HEIGHT = CELL_WIDTH*6
const LINE_WIDTH = 4.0
const TICK_WIDTH = 1.0
const COL = Color.gray

func _ready():
	pass # Replace with function body.

func _draw():
	draw_line(Vector2(CELL_WIDTH, 0), Vector2(CELL_WIDTH, BOARD_HEIGHT), COL, LINE_WIDTH)
	draw_line(Vector2(BOARD_WIDTH-CELL_WIDTH, 0), Vector2(BOARD_WIDTH-CELL_WIDTH, BOARD_HEIGHT), COL, LINE_WIDTH)
	draw_line(Vector2(0, CELL_WIDTH*2), Vector2(BOARD_WIDTH, CELL_WIDTH*2), COL, LINE_WIDTH)
	draw_line(Vector2(0, CELL_WIDTH*4), Vector2(BOARD_WIDTH, CELL_WIDTH*4), COL, LINE_WIDTH)
	for i in range(3):
		draw_line(Vector2(0, CELL_WIDTH*(i*2+1)), Vector2(CELL_WIDTH, CELL_WIDTH*(i*2+1)), COL, TICK_WIDTH)
		draw_line(Vector2(BOARD_WIDTH-CELL_WIDTH, CELL_WIDTH*(i*2+1)), Vector2(BOARD_WIDTH, CELL_WIDTH*(i*2+1)), COL, TICK_WIDTH)
