extends Node2D

const _random_keys: Dictionary = {
	KEY_1: 1,
	KEY_2: 5,
	KEY_3: 10,
	KEY_4: 15,
	KEY_5: 20,
	KEY_6: 25,
	KEY_7: 30,
	KEY_8: 35,
	KEY_9: 40,
}

@export_range(5, 100, 5) var _cell_size: int

@export_group("Colors")
@export var _bg_color: Color
@export var _cell_color: Color
@export var _grid_color: Color

@onready var _step_timer: Timer = $StepTimer

var _cells: Array
var _cells_flip: Array

var _exit_thread: bool
var _mutex: Mutex
var _semaphore: Semaphore
var _threads: Array[Thread]
var _threads_finished = 0


func _cell_click(coords: Vector2) -> void:
	var x: float = floor(coords.x / _cell_size)
	var y: float = floor(coords.y / _cell_size)
	
	_cells[x][y] = !_cells[x][y]
	
	queue_redraw()


func _clear_flip() -> void:
	for x in range(_cells_flip.size()):
		for y in range(_cells_flip[x].size()):
			_cells_flip[x][y] = false


func _draw() -> void:
	_draw_background()
	_draw_cells()
	_draw_grid()


func _draw_background() -> void:
	draw_rect(get_viewport_rect(), _bg_color)


func _draw_cells() -> void:
	for x in range(_cells.size()):
		for y in range(_cells[x].size()):
			if _cells[x][y]:
				var rect: Rect2 = Rect2(x * _cell_size, y * _cell_size, _cell_size, _cell_size)
				draw_rect(rect, _cell_color)


func _draw_grid() -> void:
	var lines: PackedVector2Array
	
	for x in range(0, get_viewport_rect().size.x, _cell_size):
		lines.append(Vector2(x, 0))
		lines.append(Vector2(x, get_viewport_rect().size.y))
	
	for y in range(0, get_viewport_rect().size.y, _cell_size):
		lines.append(Vector2(0, y))
		lines.append(Vector2(get_viewport_rect().size.x, y))
	
	draw_multiline(lines, _grid_color)


func _get_neighbour(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x > _cells.size() - 1 or y > _cells[x].size() - 1:
		return false
	
	return _cells[x][y]


func _get_neighbours(x: int, y: int) -> int:
	var count: int = 0
	
	#top
	count += int(_get_neighbour(x, y - 1))
	
	#top-right
	count += int(_get_neighbour(x + 1, y - 1))
	
	#right
	count += int(_get_neighbour(x + 1, y))
	
	#bottom-right
	count += int(_get_neighbour(x + 1, y + 1))
	
	#bottom
	count += int(_get_neighbour(x, y + 1))
	
	#bottom-left
	count += int(_get_neighbour(x - 1, y + 1))
	
	#left
	count += int(_get_neighbour(x - 1, y))
	
	#top-left
	count += int(_get_neighbour(x - 1, y - 1))
	
	return count


func _exit_tree() -> void:
	_mutex.lock()
	_exit_thread = true
	_mutex.unlock()
	
	for x in range(_cells.size()):
		_semaphore.post()
	
	for thread in _threads:
		thread.wait_to_finish()


func _init_cells() -> void:
	for x in range(0, (get_viewport_rect().size.x / _cell_size)):
		_cells.append([])
		_cells_flip.append([])
		
		for y in range(0, (get_viewport_rect().size.y / _cell_size)):
			_cells[x].append(false)
			_cells_flip[x].append(false)


func _init_threads() -> void:
	_exit_thread = false
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	
	for c in _cells:
		_threads.append(Thread.new())
		
	for x in range(_cells.size()):
		_threads[x].start(_process_cell_col.bind(x))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		_cell_click(event.position)
	
	if event.is_action_pressed("step"):
		if _step_timer.is_stopped():
			_step()
	
	if event.is_action_pressed("toggle"):
		if _step_timer.is_stopped():
			_step()
		
		_toggle_step()
	
	if event.is_action_pressed("randomise"):
		_randomise_cells(_random_keys[event.key_label])


func _on_step_timer_timeout() -> void:
	_step()


func _process_cells() -> void:
	_threads_finished = 0
	
	for x in range(_cells.size()):
		_semaphore.post()
		#_process_cell_col(x)
	
	while _threads_finished < _cells.size():
		pass
	
	_cells = _cells_flip.duplicate(true)


func _process_cell_col(x: int) -> void:
	while true:
		_semaphore.wait()
		
		_mutex.lock()
		var should_exit: bool = _exit_thread
		_mutex.unlock()
		
		if should_exit:
			break
		
		for y in range(_cells[x].size()):
			var neighbours: int = _get_neighbours(x, y)
			
			_mutex.lock()
			
			if _cells[x][y]:
				if neighbours < 2:
					_cells_flip[x][y] = false
				elif neighbours > 3:
					_cells_flip[x][y] = false
				else:
					_cells_flip[x][y] = true
			else:
				if neighbours == 3:
					_cells_flip[x][y] = true
					
			_mutex.unlock()
		
		_mutex.lock()
		_threads_finished += 1
		_mutex.unlock()


func _randomise_cells(amount: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	
	rng.randomize()
	
	for x in range(_cells.size()):
		for y in range(_cells[x].size()):
			var state: bool = true if rng.randi_range(0, amount) == 0 else false
			
			_cells[x][y] = state
	
	queue_redraw()


func _ready() -> void:
	_init_cells()
	_init_threads()


func _step() -> void:
	_process_cells()
	_clear_flip()
	
	queue_redraw()


func _toggle_step() -> void:
	if _step_timer.is_stopped():
		_step_timer.start()
	else:
		_step_timer.stop()
