extends Node2D

const CELL_WIDTH = 64
const LABEL_HEIGHT = 28
const TILE_NONE = -1
const TILE_GRAY = 0
const TILE_DST = 1
const LEFT_X = 0
const RIGHT_X = 4
const LEFT_DICE_X = -1
const RIGHT_DICE_X = 5
const DICE_Y = 0
enum {
	MODE_INIT = 0,
	MODE_HAI_HUMAN,		# 先手（左側）：ヒューリスティックAI、後手：人間
	MODE_RAND_RAND,
	MODE_HAI_RAND,		# 先手（左側）：ヒューリスティックAI、後手：ランダム
}

var mode = MODE_INIT
var nEpisode = 0
var nEpisodeRest = 0
var nLeftWon = 0
var nRightWon = 0
var nDraw = 0
var nLTgtRT = 0
var nLTltRT = 0
var left_turn = true		# 左側の手番
var dice = 0
var labels = []				# 大小比較結果ラベル
var CmpLabel = load("res://CmpLabel.tscn")
var rng = RandomNumberGenerator.new()

func _ready():
	for i in range(3):
		var y = (i+1)*2*CELL_WIDTH - LABEL_HEIGHT
		var l = CmpLabel.instance()
		l.rect_position = Vector2(CELL_WIDTH, y)
		l.text = ""
		$Board.add_child(l)
		labels.push_back(l)
	pass # Replace with function body.
