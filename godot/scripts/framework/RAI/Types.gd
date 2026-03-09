class_name Types
enum Type {
	INT8,
	UINT8,
	INT16,
	UINT16,
	INT32,
	UINT32,
	FLOAT,
	DOUBLE,
	VEC2F,
	VEC3F,
	VEC2I,
	VEC3I,
	STRING,
	PACKED_BYTES,
	PACKED_FLOAT,
	PACKED_INT32
}

static func sizeof(type: Type) -> int:
	match type:
		Type.INT8: return  1
		Type.UINT8: return  1
		Type.INT16: return  2
		Type.UINT16: return  2
		Type.INT32: return  4
		Type.UINT32: return  4
		Type.FLOAT: return  4
		Type.DOUBLE: return  4
		Type.VEC2F: return  8
		Type.VEC3F: return  12
		Type.VEC2I: return  8
		Type.VEC3I: return  12
		Type.STRING: return 1
		Type.PACKED_BYTES: return 1
		Type.PACKED_FLOAT: return  4
		Type.PACKED_INT32: return  4
		_: return 0
static func is_variable_length(type: Type):
	match type:
		Type.STRING: return true	
		Type.PACKED_BYTES: return true
		Type.PACKED_FLOAT: return true
		Type.PACKED_INT32: return true
		_: return false
static func is_string_type(type: Type):
	return type == Type.STRING

static func encode(value: Variant, type: Type) -> PackedByteArray:
	if is_variable_length(type):
		return _encode_variable_length(value, type)
	else:
		return _encode_fixed_length(value, type)
	
static func _encode_fixed_length(value: Variant, type: Type):
	var data: PackedByteArray = PackedByteArray()
	data.resize(sizeof(type))
	match type:
		Type.INT8:
			data.encode_s8(0, value)
		Type.UINT8:
			data.encode_u8(0, value)
		Type.INT16:
			data.encode_s16(0, value)
		Type.UINT16:
			data.encode_u16(0, value)
		Type.INT32:
			data.encode_s32(0, value)
		Type.FLOAT:
			data.encode_float(0, value)
		Type.DOUBLE:
			data.encode_double(0, value)
		Type.VEC2F:
			data.encode_float(0, value.x)
			data.encode_float(0 + 4, value.y)
		Type.VEC3F:
			data.encode_float(0, value.x)
			data.encode_float(0 + 4, value.y)
			data.encode_float(0 + 8, value.z)
		Type.VEC2I:
			data.encode_s32(0, value.x)
			data.encode_s32(0 + 4, value.y)
		Type.VEC3I:
			data.encode_s32(0, value.x)
			data.encode_s32(0 + 4, value.y)
			data.encode_s32(0 + 8, value.z)
	return data
static func _encode_variable_length(value: Variant, type: Type) -> PackedByteArray:
	match type:
		Type.STRING:
			return (value as String).to_utf8_buffer()
		Type.PACKED_BYTES:
			return value
		Type.PACKED_FLOAT:
			return (value as PackedFloat32Array).to_byte_array()
		Type.PACKED_INT32:
			return (value as PackedInt32Array).to_byte_array()
		_: # !unreachable
			push_error("unreachable")
			return PackedByteArray()


static func decode(data: PackedByteArray, type: Type) -> Variant:
	if is_variable_length(type):
		return _decode_variable_length(data, type)
	else:
		return _decode_fixed_length(data, type)

static func decode_sequence(data: PackedByteArray, types: Array[Type]) -> Array[Variant]:
	var offset:= 0
	var result := []
	for type in types:
		var size:= sizeof(type)
		var next = decode(data.slice(offset, offset+size), type); offset+= size
		result.push_back(next)
	return result
		

static func _decode_fixed_length(data: PackedByteArray, type: Type) -> Variant:
	match type:
		Type.INT8:
			return data.decode_s8(0)
		Type.UINT8:
			return data.decode_u8(0)
		Type.INT16:
			return data.decode_s16(0)
		Type.UINT16:
			return data.decode_u16(0)
		Type.INT32:
			return data.decode_s32(0)
		Type.UINT32:
			return data.decode_u32(0)
		Type.FLOAT:
			return data.decode_float(0)
		Type.DOUBLE:
			return data.decode_double(0)
		Type.VEC2F:
			return Vector2(
				data.decode_float(0),
				data.decode_float(0 + 4)
			)
		Type.VEC3F:
			return Vector3(
				data.decode_float(0),
				data.decode_float(0 + 4),
				data.decode_float(0 + 8)
			)
		Type.VEC2I:
			return Vector2i(
				data.decode_s32(0),
				data.decode_s32(0 + 4)
			)
		Type.VEC3I:
			return Vector3i(
				data.decode_s32(0),
				data.decode_s32(0 + 4),
				data.decode_s32(0 + 8)
			)
		_: 
			return null
static func _decode_variable_length(data: PackedByteArray, type: Type) -> Variant:
	match type:
		Type.STRING:
			return data.get_string_from_utf8()
		Type.PACKED_BYTES:
			return data
		Type.PACKED_FLOAT:
			return data.to_float32_array()
		Type.PACKED_INT32:
			return data.to_int32_array()
		_: # !unreachable
			push_error("unreachable")
			return PackedByteArray()
