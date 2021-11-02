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
	MODE_HUMAN_RAND,	# 先手（左側）：人間、後手：ランダム
	MODE_RAND_HUMAN,	# 先手（左側）：ランダム、後手：人間
	MODE_HUMAN_HAI,		# 先手（左側）：人間、後手：ヒューリスティックAI
	#MODE_HUAI_HUM,		# 先手（左側）：ヒューリスティックAI、後手：人間
	MODE_HAI_HUMAN,		# 先手（左側）：ヒューリスティックAI、後手：人間
	MODE_RAND_RAND,
	MODE_RAND_HAI,
	MODE_HAI_RAND,		# 先手（左側）：ヒューリスティックAI、後手：ランダム
}

var mode = MODE_INIT
var last_mode = -1
var nEpisode = 0
var nEpisodeRest = 0
var nLeftWon = 0
var nRightWon = 0
var nDraw = 0
var nLTgtRT = 0
var nLTltRT = 0
var left_turn = true		# 左側の手番
var dice = 0
var wcnt = 0				# ウェイト用カウンタ
var expected_table_10 = []		# slf:[0, d1], opo:[0, 0] の場合の期待値、ix = d1 - 1
var expected_table_11 = []		# slf:[0, d1], opo:[0, d3] の場合の期待値、ix = (d1-1)*6 + d3-1
var expected_table_20 = []		# slf:[d0, d1], opo:[0, 0] の場合の期待値、ix = (d0-1)*6 + (d1-1)
var expected_table_21 = []		# slf:[d0, d1], opo:[0, d3] の場合の期待値、ix = ((d0-1)*6 + (d1-1))*6 + d3-1
var labels = []				# 大小比較結果ラベル
var Q = []					# Q値テーブル
var CmpLabel = load("res://CmpLabel.tscn")
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	Q.resize(11*11*11*64)
	build_expected_table()
	clear_dice()
	clear_cursor()
	for i in range(3):
		var y = (i+1)*2*CELL_WIDTH - LABEL_HEIGHT
		var l = CmpLabel.instance()
		l.rect_position = Vector2(CELL_WIDTH, y)
		l.text = ""
		$Board.add_child(l)
		labels.push_back(l)
	assert( quantize_exp_val(-1.0) == 0 )
	assert( quantize_exp_val(-0.4) == 3 )
	assert( quantize_exp_val(-0.2) == 4 )
	assert( quantize_exp_val(0.0) == 5 )
	assert( quantize_exp_val(0.2) == 6 )
	assert( quantize_exp_val(0.4) == 7 )
	assert( quantize_exp_val(1.0) == 10 )
	#
	"""
	var slf = [0, 0]
	var opo = [0, 0]
	#print(expected_value2(slf, opo))
	#for i in range(6):
	#	slf[1] = i + 1
	#	print(expected_value2(slf, opo), ", ", expected_value0(slf, opo))
	#	#assert( expected_value0(slf, opo) == expected_value2(slf, opo) )
	for d0 in range(7):
		slf[0] = d0
		for d1 in range(7):
			if d0 != 0 && d1 == 0: continue
			slf[1] = d1
			for d2 in range(7):
				opo[0] = d2
				for d3 in range(7):
					if d2 != 0 && d3 == 0: continue
					opo[1] = d3
					if expected_value2(slf, opo) != expected_value0(slf, opo):
						print(d0, d1, d2, d3, ": ", expected_value2(slf, opo), ", ", expected_value0(slf, opo))
	"""
	pass
func build_expected_table():
	expected_table_10.resize(6)
	for d1 in range(1, 7):		# [1, 6]
		var sum = 0.0
		for t0 in range(1, 7):
			for t2 in range(1, 7):
				for t3 in range(1, 7):
					var d0d1 = t0 * d1
					var d2d3 = t2 * t3
					if d0d1 < d2d3: sum -= 1.0
					elif d0d1 > d2d3: sum += 1.0
		expected_table_10[d1-1] = sum / (6*6*6)
	print(expected_table_10, "\n")

	expected_table_11.resize(6*6)
	for d1 in range(1, 7):		# [1, 6]
		for d3 in range(1, 7):		# [1, 6]
			var sum = 0.0
			for t0 in range(1, 7):
				for t2 in range(1, 7):
					var d0d1 = t0 * d1
					var d2d3 = t2 * d3
					if d0d1 < d2d3: sum -= 1.0
					elif d0d1 > d2d3: sum += 1.0
			expected_table_11[(d1-1)*6+d3-1] = sum / (6*6)
	#print(expected_table_11)
	for i in range(6):
		var ix = i * 6
		print(expected_table_11.slice(ix, ix+5))

	# slf:[d0, d1], opo:[0, 0] の場合の期待値、ix = (d0-1)*6 + (d1-1)
	expected_table_20.resize(6*6)
	for d0 in range(1, 7):		# [1, 6]
		for d1 in range(1, 7):		# [1, 6]
			var sum = 0.0
			for t2 in range(1, 7):
				for t3 in range(1, 7):
					var d0d1 = d0 * d1
					var d2d3 = t2 * t3
					if d0d1 < d2d3: sum -= 1.0
					elif d0d1 > d2d3: sum += 1.0
			expected_table_20[(d0-1)*6+d1-1] = sum / (6*6)
	#print(expected_table_11)
	print("")
	for i in range(6):
		var ix = i * 6
		print(expected_table_20.slice(ix, ix+5))

	# slf:[d0, d1], opo:[0, d3] の場合の期待値、ix = ((d0-1)*6 + (d1-1))*6 + d3-1
	expected_table_21.resize(6*6*6)
	for d0 in range(1, 7):		# [1, 6]
		for d1 in range(1, 7):		# [1, 6]
			for d3 in range(1, 7):		# [1, 6]
				var sum = 0.0
				for t2 in range(1, 7):
					var d0d1 = d0 * d1
					var d2d3 = t2 * d3
					if d0d1 < d2d3: sum -= 1.0
					elif d0d1 > d2d3: sum += 1.0
				expected_table_21[((d0-1)*6 + (d1-1))*6+d3-1] = sum / (6)
func clear_dice():
	for y in range(6):
		$Board/DiceTileMap.set_cell(LEFT_X, y, TILE_NONE)
		$Board/DiceTileMap.set_cell(RIGHT_X, y, TILE_NONE)
func clear_cursor():
	for y in range(6):
		$Board/CurTileMap.set_cell(LEFT_X, y, TILE_NONE)
		$Board/CurTileMap.set_cell(RIGHT_X, y, TILE_NONE)
func get_dice(x, y):		# 0 for NONE, [1, 6] for Dice
	return $Board/DiceTileMap.get_cell(x, y) + 1
func set_dice(x, y, d):		# 0 for NONE, [1, 6] for Dice
	$Board/DiceTileMap.set_cell(x, y, d-1)
func is_game_over():
	return (get_dice(LEFT_X, 0) != 0 && get_dice(LEFT_X, 2) != 0 && get_dice(LEFT_X, 4) != 0 &&
			get_dice(RIGHT_X, 0) != 0 && get_dice(RIGHT_X, 2) != 0 && get_dice(RIGHT_X, 4) != 0)
func judge_won_lose():		# +1 for left won, -1 for right won, 0 for draw
	nLTgtRT = 0
	nLTltRT = 0
	for i in range(3):
		var y = i * 2
		var ld0 = get_dice(LEFT_X, y)
		var rd0 = get_dice(RIGHT_X, y)
		if ld0 != 0 && rd0 != 0:
			var ld1 = get_dice(LEFT_X, y+1)
			var rd1 = get_dice(RIGHT_X, y+1)
			var lt = ld0 * ld1
			var rt = rd0 * rd1
			#if lt > rt: nLeftWon += 1
			#elif lt < rt: nRightWon += 1
			#else: nDraw += 1
			if lt > rt: nLTgtRT += 1
			elif lt < rt: nLTltRT += 1
	if nLTgtRT > nLTltRT: return 1
	if nLTgtRT < nLTltRT: return -1
	return 0
func update_cursor():		# 勝ち負けが確定したら、負けた方をグレイアウト
	nLTgtRT = 0
	nLTltRT = 0
	for i in range(3):
		var y = i * 2
		var ld0 = get_dice(LEFT_X, y)
		var rd0 = get_dice(RIGHT_X, y)
		if ld0 != 0 && rd0 != 0:
			var ld1 = get_dice(LEFT_X, y+1)
			var rd1 = get_dice(RIGHT_X, y+1)
			var lt = ld0 * ld1
			var rt = rd0 * rd1
			#if lt > rt: nLeftWon += 1
			#elif lt < rt: nRightWon += 1
			#else: nDraw += 1
			if lt > rt: nLTgtRT += 1
			elif lt < rt: nLTltRT += 1
			$Board/CurTileMap.set_cell(LEFT_X, y, TILE_GRAY if lt < rt else TILE_NONE)
			$Board/CurTileMap.set_cell(LEFT_X, y+1, TILE_GRAY if lt < rt else TILE_NONE)
			$Board/CurTileMap.set_cell(RIGHT_X, y, TILE_GRAY if lt > rt else TILE_NONE)
			$Board/CurTileMap.set_cell(RIGHT_X, y+1, TILE_GRAY if lt > rt else TILE_NONE)
			var op : String = ">" if lt > rt else "<" if lt < rt else "=="
			labels[i].text = "%d*%d %s %d*%d" % [ld0, ld1, op, rd0, rd1]
		else:
			$Board/CurTileMap.set_cell(LEFT_X, y, TILE_NONE)
			$Board/CurTileMap.set_cell(LEFT_X, y+1, TILE_NONE)
			$Board/CurTileMap.set_cell(RIGHT_X, y, TILE_NONE)
			$Board/CurTileMap.set_cell(RIGHT_X, y+1, TILE_NONE)
			labels[i].text = ""
func set_dst_cursor(x):
		for i in range(3):
			var y = i * 2
			if get_dice(x, y+1) == 0:
				$Board/CurTileMap.set_cell(x, y+1, TILE_DST)
			elif get_dice(x, y) == 0:
				$Board/CurTileMap.set_cell(x, y, TILE_DST)
func sel_move_randomly(x):
	var lst = []
	for i in range(3):
		var y = i * 2
		if get_dice(x, y+1) == 0:
			lst.push_back(y+1)
		elif get_dice(x, y) == 0:
			lst.push_back(y)
	if lst.empty(): return -1
	if lst.size() == 1: return lst[0]
	return lst[rng.randi_range(0, lst.size() - 1)]
func get_qix(x1, x2):		# TileMap の陸海空状態からQ値辞書キーを計算
	#var ev1 = quantize_exp_val(expected_value([get_dice(x1, 0), get_dice(x1, 1)], [get_dice(x2, 0), get_dice(x2, 1)]))
	#var ev2 = quantize_exp_val(expected_value([get_dice(x1, 2), get_dice(x1, 3)], [get_dice(x2, 2), get_dice(x2, 3)]))
	#var ev3 = quantize_exp_val(expected_value([get_dice(x1, 4), get_dice(x1, 5)], [get_dice(x2, 4), get_dice(x2, 5)]))
	#var lst = []
	var ix : int = 0
	var e : int = 0			# 6bit数値
	for i in range(3):
		var y = i * 2
		var d0 = get_dice(x1, y)
		var d1 = get_dice(x1, y + 1)
		var d2 = get_dice(x2, y)
		var d3 = get_dice(x2, y + 1)
		#lst.push_back(quantize_exp_val(expected_value([d0, d1], [d2, d3])))
		ix = ix * 11 + quantize_exp_val(expected_value([d0, d1], [d2, d3]))
		e <<= 1
		if d0 == 0 || d1 == 0: e += 1
		e <<= 1
		if d2 == 0 || d3 == 0: e += 1
	return ix * 64 + e		# 64 = 2^6
func quantize_exp_val(val:float) -> int:	# [-1.0, +1.0] -> [0, 1, 2, ... 10]、[-1.0, -0.9] -> 0, 0.0 -> 5
	#print(int(val / 0.2 + 0.5)) 
	return int(round(val / 0.2)) + 5
func expected_value(slf, opo) -> float:	# サイコロ２つまでの、slf から見た期待値 [-1, 1] を計算
	return expected_value2(slf, opo)
# --opo: [0, d2], lft: [0, 0] のように、opo の方がダイス数が多いか等しいものとする--
func expected_value2(slf, opo) -> float:	# サイコロ２つまでの、slf から見た期待値 [-1, 1] を計算
	if opo == slf: return 0.0
	var d0 = slf[0]
	var d1 = slf[1]
	var d2 = opo[0]
	var d3 = opo[1]
	if d0 == 0:	# lt: [0, ?], rt: [?, ?]
		if d2 == 0:	# lt: [0, ?], rt: [0, ?]
			if d1 == 0:	# lt: [0, 0], rt: [0, d3]
				assert( d3 != 0 )
				return -expected_table_10[d3-1]
			else:				# lt: [0, d1], rt: [0, ?]
				if d3 == 0:		# lt: [0, d1], rt: [0, 0]
					return expected_table_10[d1-1]
				else:		# lt: [0, d1], rt: [0, d3]
					return expected_table_11[(d1-1)*6 + d3-1]
		else:				# lt: [0, ?], rt: [d2, ?]
			return -expected_value2(opo, slf)
	else:
		if d2 == 0:		# lt: [d0, d1], rt: [0, ?]
			assert( d1 != 0 )
			if d3 == 0:		# lt: [d0, d1], rt: [0, 0]
				return expected_table_20[(d0-1)*6 + (d1-1)]
			else:			# lt: [d0, d1], rt: [0, d3]
				return expected_table_21[((d0-1)*6 + (d1-1))*6 + d3-1]
		else:				# lt: [d0, d1], rt: [d2, d3]
			var d0d1 = d0 * d1
			var d2d3 = d2 * d3
			if d0d1 > d2d3: return 1.0
			if d0d1 < d2d3: return -1.0
			return 0.0
func expected_value0(slf, opo) -> float:	# サイコロ２つまでの、slf から見た期待値 [-1, 1] を計算
	if opo == slf: return 0.0
	var d0 = opo[0]
	var d1 = opo[1]
	var d2 = slf[0]
	var d3 = slf[1]
	if d0 == 0:	# lt: [0, ?], rt: [?, ?]
		if d2 == 0:	# lt: [0, ?], rt: [0, ?]
			if d1 == 0:	# lt: [0, 0], rt: [0, d3]
				assert( d3 != 0 )
				return -expected_value0(opo, slf)
			else:				# lt: [0, d1], rt: [0, ?]
				if d3 == 0:		# lt: [0, d1], rt: [0, 0]
					var sum = 0.0
					for t0 in range(1, 7):
						for t2 in range(1, 7):
							for t3 in range(1, 7):
								var d0d1 = t0 * d1
								var d2d3 = t2 * t3
								if d0d1 > d2d3: sum -= 1.0
								elif d0d1 < d2d3: sum += 1.0
					return sum / (6*6*6)
				else:		# lt: [0, d1], rt: [0, d3]
					var sum = 0.0
					for t0 in range(1, 7):
						for t2 in range(1, 7):
								var d0d1 = t0 * d1
								var d2d3 = t2 * d3
								if d0d1 > d2d3: sum -= 1.0
								elif d0d1 < d2d3: sum += 1.0
					return sum / (6*6)
		else:				# lt: [0, ?], rt: [d2, ?]
			return -expected_value0(opo, slf)
		pass
	else:				# lt: [d0, ?], rt: [?, ?]
		if d2 == 0:		# lt: [d0, d1], rt: [0, ?]
			assert( d1 != 0 )
			if d3 == 0:		# lt: [d0, d1], rt: [0, 0]
				var sum = 0.0
				for t2 in range(1, 7):
					for t3 in range(1, 7):
						var d0d1 = d0 * d1
						var d2d3 = t2 * t3
						if d0d1 > d2d3: sum -= 1.0
						elif d0d1 < d2d3: sum += 1.0
				return sum / (6*6)
			else:		# lt: [d0, d1], rt: [0, d3]
				var sum = 0.0
				for t2 in range(1, 7):
					var d0d1 = d0 * d1
					var d2d3 = t2 * d3
					if d0d1 > d2d3: sum -= 1.0
					elif d0d1 < d2d3: sum += 1.0
				return sum / (6)
		else:				# lt: [d0, d1], rt: [d2, d3]
			var d0d1 = d0 * d1
			var d2d3 = d2 * d3
			if d0d1 > d2d3: return -1.0
			if d0d1 < d2d3: return 1.0
			return 0.0
	return 999.0
func input_X_human():		# 左側：人間以外、右側：人間
	if get_dice(RIGHT_X, 0) != 0 && get_dice(RIGHT_X, 2) != 0 && get_dice(RIGHT_X, 4) != 0:
		mode = MODE_INIT
		return
	if !left_turn:
		if !dice:
			dice = rng.randi_range(1, 6)
			set_dice(RIGHT_DICE_X, DICE_Y, dice)
			set_dst_cursor(RIGHT_X)
		else:
			var mp = $Board/CurTileMap.world_to_map($Board/CurTileMap.get_local_mouse_position())
			if $Board/CurTileMap.get_cellv(mp) == TILE_DST:
				set_dice(RIGHT_DICE_X, DICE_Y, TILE_NONE)
				set_dice(mp.x, mp.y, dice)
				dice = 0
				update_cursor()
				left_turn = !left_turn
				if is_game_over():
					var rslt = judge_won_lose()
					if rslt > 0:
						$NEpiLabel.text = "Left won"
						nLeftWon += 1
					elif rslt < 0:
						$NEpiLabel.text = "Right won"
						nRightWon += 1
					else:
						$NEpiLabel.text = "Draw"
						nDraw += 1
					nEpisode += 1
					update_stats_label()
					mode = MODE_INIT
				else:
					$NEpiLabel.text = ""
	#print("")
	#for i in range(3):
	#	var y = i * 2
	#	var left = [get_dice(LEFT_X, y), get_dice(LEFT_X, y+1)]
	#	var right = [get_dice(RIGHT_X, y), get_dice(RIGHT_X, y+1)]
	#	print("exp val = ", expected_value(right, left))
func input_human_X():		# 左側（先手）：人間 vs 右側（後手）：ランダム、AI など人間以外
	$NEpiLabel.text = ""
	if left_turn:
		if get_dice(RIGHT_X, 0) != 0 && get_dice(RIGHT_X, 2) != 0 && get_dice(RIGHT_X, 4) != 0:
			#mode = MODE_INIT
			dice = 0
			clear_dice()
			left_turn = true
			return
		if !dice:
			dice = rng.randi_range(1, 6)
			set_dice(LEFT_DICE_X, DICE_Y, dice)
			set_dst_cursor(LEFT_X)
			$NEpiLabel.text = "Click dst pos"
		else:
			var mp = $Board/CurTileMap.world_to_map($Board/CurTileMap.get_local_mouse_position())
			if $Board/CurTileMap.get_cellv(mp) == TILE_DST:
				set_dice(LEFT_DICE_X, DICE_Y, TILE_NONE)
				set_dice(mp.x, mp.y, dice)
				dice = 0
				update_cursor()
				left_turn = !left_turn
				$NEpiLabel.text = ""
#func input_hai_human():
#	if !left_turn:
#		if get_dice(LEFT_X, 0) != 0 && get_dice(LEFT_X, 2) != 0 && get_dice(LEFT_X, 4) != 0:
#			#mode = MODE_INIT
#			dice = 0
#			clear_dice()
#			left_turn = true
#			return
#		if !dice:
#			dice = rng.randi_range(1, 6)
#			set_dice(RIGHT_DICE_X, DICE_Y, dice)
#			set_dst_cursor(RIGHT_X)
#			$NEpiLabel.text = "Click dst pos"
#		else:
#			var mp = $Board/CurTileMap.world_to_map($Board/CurTileMap.get_local_mouse_position())
#			if $Board/CurTileMap.get_cellv(mp) == TILE_DST:
#				set_dice(RIGHT_DICE_X, DICE_Y, TILE_NONE)
#				set_dice(mp.x, mp.y, dice)
#				dice = 0
#				update_cursor()
#				left_turn = !left_turn
#				if is_game_over():
#					var rslt = judge_won_lose()
#					if rslt > 0: $NEpiLabel.text = "Left won"
#					elif rslt < 0: $NEpiLabel.text = "Right won"
#					else: $NEpiLabel.text = "Draw"
#					mode = MODE_INIT
#				else:
#					$NEpiLabel.text = ""
func _input(event):
	if event is InputEventMouseButton && event.is_pressed():
		if mode == MODE_RAND_HUMAN || mode == MODE_HAI_HUMAN:
			input_X_human()
		elif mode == MODE_HUMAN_RAND || mode == MODE_HUMAN_HAI:
			input_human_X()
func sel_move_heuristic(slf, opo):
	var mx = -999
	var mi = -1
	for i in range(3):
		var y = i*2
		if get_dice(slf, y) != 0: continue	# slf: [d0, d1] の場合
		var slfa = [get_dice(slf, y), get_dice(slf, y+1)]
		var opoa = [get_dice(opo, y), get_dice(opo, y+1)]
		var ev0 = expected_value(slfa, opoa)
		if get_dice(slf, y+1) == 0:		# slf: [0, 0] の場合
			slfa[1] = dice
		else:							# slf: [0, d1] の場合
			slfa[0] = dice
		var de = expected_value(slfa, opoa) - ev0
		if de > mx:
			mx = de
			mi = i
	var y = mi * 2
	if get_dice(slf, y+1) == 0:		# slf: [0, 0] の場合
		return y + 1
	else:
		return y
func update_stats_label():
	$StatsLabel.text = "%d-%d-%d / %d" % [nLeftWon, nDraw, nRightWon, nEpisode]
func process_rand_rand():
	$NEpiLabel.text = "#%d" % (nEpisode+1)
	clear_dice()
	while true:
		var d = rng.randi_range(1, 6)
		var x = LEFT_X if left_turn else RIGHT_X
		var y = sel_move_randomly(x)
		if y < 0:
			update_cursor()
			nEpisode += 1
			nEpisodeRest -= 1
			if nLTgtRT > nLTltRT: nLeftWon += 1
			elif nLTgtRT < nLTltRT: nRightWon += 1
			else: nDraw += 1
			update_stats_label()
			left_turn = true		# 常に左側が先手とする
			if nEpisodeRest == 0:
				print("nLeftWon = ", nLeftWon)
				print("nRightWon = ", nRightWon)
				print("nDraw = ", nDraw)
				mode = MODE_INIT
			break
		else:
			set_dice(x, y, d)
			left_turn = !left_turn
func process_rand_hai():
	clear_dice()
	while true:
		dice = rng.randi_range(1, 6)
		var x = LEFT_X if left_turn else RIGHT_X
		var y
		if left_turn:
			y = sel_move_randomly(x)
		else:
			y = sel_move_heuristic(RIGHT_X, LEFT_X)
		if y < 0:
			update_cursor()
			nEpisode += 1
			nEpisodeRest -= 1
			if nLTgtRT > nLTltRT: nLeftWon += 1
			elif nLTgtRT < nLTltRT: nRightWon += 1
			else: nDraw += 1
			update_stats_label()
			left_turn = true		# 常に左側が先手とする
			if nEpisodeRest == 0:
				print("nLeftWon = ", nLeftWon)
				print("nRightWon = ", nRightWon)
				print("nDraw = ", nDraw)
				mode = MODE_INIT
			break
		else:
			set_dice(x, y, dice)
			left_turn = !left_turn
func process_hai_rand():
	clear_dice()
	while true:
		dice = rng.randi_range(1, 6)
		var x = LEFT_X if left_turn else RIGHT_X
		var y
		if left_turn:
			y = sel_move_heuristic(LEFT_X, RIGHT_X)
		else:
			y = sel_move_randomly(x)
		if y < 0:
			update_cursor()
			nEpisode += 1
			nEpisodeRest -= 1
			if nLTgtRT > nLTltRT: nLeftWon += 1
			elif nLTgtRT < nLTltRT: nRightWon += 1
			else: nDraw += 1
			left_turn = true		# 常に左側が先手とする
			if nEpisodeRest == 0:
				print("nLeftWon = ", nLeftWon)
				print("nRightWon = ", nRightWon)
				print("nDraw = ", nDraw)
				mode = MODE_INIT
			break
		else:
			set_dice(x, y, dice)
			left_turn = !left_turn
func process_hai_human():
	if !left_turn: return
	if get_dice(LEFT_X, 0) != 0 && get_dice(LEFT_X, 2) != 0 && get_dice(LEFT_X, 4) != 0:
		mode = MODE_INIT
		return
	if !dice:	# ダイスが振られていない場合
		dice = rng.randi_range(1, 6)
		set_dice(LEFT_DICE_X, DICE_Y, dice)
		wcnt = 30
	else:
		wcnt -= 1
		if wcnt > 0: return
		var y = sel_move_heuristic(LEFT_X, RIGHT_X)
		if y >= 0:
			set_dice(LEFT_X, y, dice)
			update_cursor()
			left_turn = !left_turn
			dice = 0
			set_dice(LEFT_DICE_X, DICE_Y, 0)
			$NEpiLabel.text = "Click to Roll dice"
func process_rand_human():
	if !left_turn: return
	if get_dice(LEFT_X, 0) != 0 && get_dice(LEFT_X, 2) != 0 && get_dice(LEFT_X, 4) != 0:
		mode = MODE_INIT
		return
	if !dice:	# ダイスが振られていない場合
		dice = rng.randi_range(1, 6)
		set_dice(LEFT_DICE_X, DICE_Y, dice)
		wcnt = 30
	else:
		wcnt -= 1
		if wcnt > 0: return
		var y = sel_move_randomly(LEFT_X)
		if y >= 0:
			set_dice(LEFT_X, y, dice)
			update_cursor()
			left_turn = !left_turn
			dice = 0
			set_dice(LEFT_DICE_X, DICE_Y, 0)
			$NEpiLabel.text = "Click to Roll dice"
func process_hum_X():		# 左側：人間 vs 右側：人間以外
	if left_turn: return
	if !dice:	# ダイスが振られていない場合
		dice = rng.randi_range(1, 6)
		set_dice(RIGHT_DICE_X, DICE_Y, dice)
		wcnt = 30
	else:
		wcnt -= 1
		if wcnt > 0: return
		var y
		if mode == MODE_HUMAN_RAND:
			y = sel_move_randomly(RIGHT_X)
		else:
			y = sel_move_heuristic(RIGHT_X, LEFT_X)
		if y >= 0:
			set_dice(RIGHT_X, y, dice)
			update_cursor()
			left_turn = !left_turn
			dice = 0
			set_dice(RIGHT_DICE_X, DICE_Y, 0)
			
			if is_game_over():
				var rslt = judge_won_lose()
				if rslt > 0:
					$NEpiLabel.text = "Left won"
					nLeftWon += 1
				elif rslt < 0:
					$NEpiLabel.text = "Right won"
					nRightWon += 1
				else:
					$NEpiLabel.text = "Draw"
					nDraw += 1
				nEpisode += 1
				update_stats_label()
				mode = MODE_INIT
			else:
				$NEpiLabel.text = "Click to Roll dice"
func process_hai_hum():
	if !left_turn: return
	if !dice:	# ダイスが振られていない場合
		dice = rng.randi_range(1, 6)
		set_dice(LEFT_DICE_X, DICE_Y, dice)
		wcnt = 30
	else:
		wcnt -= 1
		if wcnt > 0: return
		var y = sel_move_heuristic(LEFT_X, RIGHT_X)
		#var y
		#if mode == MODE_HUMAN_RAND:
		#	y = sel_move_randomly(LEFT_X)
		#else:
		#	y = sel_move_heuristic(LEFT_X, RIGHT_X)
		if y >= 0:
			set_dice(LEFT_X, y, dice)
			update_cursor()
			left_turn = !left_turn
			dice = 0
			set_dice(LEFT_DICE_X, DICE_Y, 0)
			
			#if is_game_over():
			#	var rslt = judge_won_lose()
			#	if rslt > 0: $NEpiLabel.text = "Left won"
			#	elif rslt < 0: $NEpiLabel.text = "Right won"
			#	else: $NEpiLabel.text = "Draw"
			#	mode = MODE_INIT
			#else:
			$NEpiLabel.text = "Click to Roll dice"
func _process(delta):
	if mode == MODE_RAND_RAND:
		process_rand_rand()
	elif mode == MODE_RAND_HAI:
		process_rand_hai()
	elif mode == MODE_HAI_RAND:
		process_hai_rand()
	elif mode == MODE_HAI_HUMAN:
		process_hai_human()
	elif mode == MODE_RAND_HUMAN:
		process_rand_human()
	elif mode == MODE_HUMAN_RAND || mode == MODE_HUMAN_HAI:
		process_hum_X()
	#elif mode == MODE_HUAI_HUM:
	#	process_hai_hum()
	pass
func clear_stats():
	nEpisode = 0
	nLeftWon = 0
	nRightWon = 0
	nDraw = 0
func _on_RxRx100_Button_pressed():		# ランダム vs ランダム x 100
	nEpisodeRest = 100
	clear_stats()
	mode = MODE_RAND_RAND
	last_mode = MODE_RAND_RAND
	clear_dice()
	left_turn = true
	pass
func _on_RxRx1000_Button_pressed():		# ランダム vs ランダム x 1000
	nEpisodeRest = 1000
	clear_stats()
	mode = MODE_RAND_RAND
	last_mode = MODE_RAND_RAND
	clear_dice()
	left_turn = true
	pass
func _on_RxHuAIx100_Button_pressed():
	nEpisodeRest = 100
	clear_stats()
	mode = MODE_RAND_HAI
	last_mode = MODE_RAND_HAI
	clear_dice()
	left_turn = true
	pass
func _on_RxHuAIx1000_Button_pressed():
	nEpisodeRest = 1000
	clear_stats()
	mode = MODE_RAND_HAI
	last_mode = MODE_RAND_HAI
	clear_dice()
	left_turn = true
	pass

func _on_HumxR_Button_pressed():		# 人間 vs ランダム
	if mode == MODE_HUMAN_RAND: return
	if last_mode != MODE_HUMAN_RAND:
		clear_stats()
		update_stats_label()
	mode = MODE_HUMAN_RAND
	last_mode = MODE_HUMAN_RAND
	dice = 0
	clear_dice()
	update_cursor()
	left_turn = true
	$NEpiLabel.text = "Click to Roll dice"
	pass
func _on_RxHum_Button_pressed():		# ランダム vs 人間
	if mode == MODE_RAND_HUMAN: return
	if last_mode != MODE_RAND_HUMAN:
		clear_stats()
		update_stats_label()
	mode = MODE_RAND_HUMAN
	last_mode = MODE_RAND_HUMAN
	dice = 0
	clear_dice()
	update_cursor()
	left_turn = true
	$NEpiLabel.text = ""
	pass
func _on_HumxHuAI_Button_pressed():		# 人間 vs ヒューリスティックAI
	if mode == MODE_HUMAN_HAI: return
	if last_mode != MODE_HUMAN_HAI:
		clear_stats()
		update_stats_label()
	mode = MODE_HUMAN_HAI
	last_mode = MODE_HUMAN_HAI
	dice = 0
	clear_dice()
	update_cursor()
	left_turn = true
	$NEpiLabel.text = "Click to Roll dice"
	pass # Replace with function body.


func _on_HuAIxHum_Button_pressed():		# ヒューリスティックAI vs 人間
	if mode == MODE_HAI_HUMAN: return
	if last_mode != MODE_HAI_HUMAN:
		clear_stats()
		update_stats_label()
	mode = MODE_HAI_HUMAN
	last_mode = MODE_HAI_HUMAN
	dice = 0
	clear_dice()
	update_cursor()
	left_turn = true
	pass # Replace with function body.


