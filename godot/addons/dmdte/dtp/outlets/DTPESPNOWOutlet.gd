class_name DTPESPNOWOutlet extends DTPOutlet

var Messages := preload("res://addons/dmdte/dtp/outlets/espnow/ESPNOWProtoMessages.gd")
@export var port: String
@export var baudrate: int

@export var peers_mac: Array[String]

var serial: GdSerial


var _control_thread: Thread
var _writer_thread: Thread
var _writer_queue_sem: Semaphore
var _writer_queue_mutex: Mutex
var _writer_queue: Array

var _reader_thread: Thread
var _threads_stop: bool = false

func _init():
	_control_thread = Thread.new()
	_writer_thread = Thread.new()
	_reader_thread = Thread.new()

func _ready() -> void:
	super._ready()
	if auto_start:
		self.begin()

func begin() -> bool:
	serial = GdSerial.new()
	
	serial.set_baud_rate(self.baudrate)
	serial.set_port(self.port)
	serial.set_timeout(1e3)
	var error := serial.open()
	if error:
		printerr(error)
		return false
		
	_writer_thread.start(_writer_thread_fn)
	_reader_thread.start(_reader_thread_fn)
	_control_thread.start(_control_thread_fn)
	
	_writer_queue_sem = Semaphore.new()
	_writer_queue_mutex = Mutex.new()
	_writer_queue = []

	return true
	

func end() -> void:
	_threads_stop = true
	_control_thread.wait_to_finish()
	_reader_thread.wait_to_finish()

	if serial.is_open():
		serial.close()
		

func _process(delta: float) -> void:

	pass


func _writer_thread_fn():
	while not _threads_stop:
		_writer_queue_sem.wait()
		_writer_queue_mutex.lock()
		
		var next = _writer_queue.pop_back()
		
		_writer_thread_send_message(next)
		while _writer_queue_sem.try_wait() and _writer_queue.size() > 0:
			next = _writer_queue.pop_back()
			_writer_thread_send_message(next)
		_writer_queue_mutex.unlock()

func _writer_thread_send_message(event: Variant):
	var bytes = event.to_bytes()
	serial.put_16(bytes.size())
	serial.put_data(bytes)
	event.free()

func _writer_thread_send(event: Variant):
	self._writer_queue_mutex.lock()
	self._writer_queue.push_back(event)
	self._writer_queue_mutex.unlock()
	self._writer_queue_sem.post()
	
func _reader_thread_fn():
	var event:= Messages.Event.new()
	while not _threads_stop:
		var size:= serial.get_16()
		if size > 0:
			var msg:= serial.get_data(size)
			event.from_bytes(msg[1])
			print(msg)
	
	event.free()

func _request_mac():
	var event:= Messages.Event.new()
	var req:= event.new_request()
	req.set_get_mac_address(true)
	_writer_thread_send(event)
	
func _request_add_peer(peer_addr: PackedByteArray):
	var event:= Messages.Event.new()
	var req:= event.new_request()
	var peer:= req.new_add_peer()
	peer.set_peer_addr(peer_addr)
	_writer_thread_send.call_deferred(event)
	
	

func _control_thread_fn():
	while not _threads_stop:
		OS.delay_msec(1)

func _exit_tree():
	end()
