#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2026, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		elif data_type == PB_DATA_TYPE.FIXED32:
			return bytes.decode_u32(index)
		elif data_type == PB_DATA_TYPE.SFIXED32:
			return bytes.decode_s32(index)
		elif data_type == PB_DATA_TYPE.FIXED64:
			return bytes.decode_u64(index)
		elif data_type == PB_DATA_TYPE.SFIXED64:
			return bytes.decode_s64(index)
		else:
			var value : int = 0
			for i in range(count):
				value |= bytes[index + i] << (8 * i)
			return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10 && i < bytes.size(): # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


enum Status {
	ESP_OK = 0,
	ESP_NOW_SEND_SUCCESS = 0,
	ESP_ERR = 1,
	ESP_NOW_FAIL = 2,
	ESP_ERR_ESPNOW_NOT_INIT = 3,
	ESP_ERR_ESPNOW_ARG = 4,
	ESP_ERR_ESPNOW_NO_MEM = 5,
	ESP_ERR_ESPNOW_FULL = 6,
	ESP_ERR_ESPNOW_NOT_FOUND = 7,
	ESP_ERR_ESPNOW_INTERNAL = 8,
	ESP_ERR_ESPNOW_EXIST = 9,
	ESP_ERR_ESPNOW_IF = 10
}

class Event:
	func _init():
		var service
		
		__request = PBField.new("request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request
		service.func_ref = Callable(self, "new_request")
		data[__request.tag] = service
		
		__reply = PBField.new("reply", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __reply
		service.func_ref = Callable(self, "new_reply")
		data[__reply.tag] = service
		
		__sent = PBField.new("sent", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __sent
		service.func_ref = Callable(self, "new_sent")
		data[__sent.tag] = service
		
		__receive = PBField.new("receive", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __receive
		service.func_ref = Callable(self, "new_receive")
		data[__receive.tag] = service
		
		__log = PBField.new("log", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __log
		service.func_ref = Callable(self, "new_log")
		data[__log.tag] = service
		
	var data = {}
	
	enum EventCase {
		EVENT_NOT_SET = 0,
		REQUEST = 1,
		REPLY = 2,
		SENT = 3,
		RECEIVE = 4,
		LOG = 5,
	}
	var _event_case: int = 0

	var __request: PBField
	func has_request() -> bool:
		return data[1].state == PB_SERVICE_STATE.FILLED
	func get_request() -> Request:
		return __request.value
	func clear_request() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request() -> Request:
		data[1].state = PB_SERVICE_STATE.FILLED
		_event_case = 1
		__reply.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__sent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__receive.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__log.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request.value = Request.new()
		return __request.value
	
	var __reply: PBField
	func has_reply() -> bool:
		return data[2].state == PB_SERVICE_STATE.FILLED
	func get_reply() -> Reply:
		return __reply.value
	func clear_reply() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__reply.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_reply() -> Reply:
		__request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		data[2].state = PB_SERVICE_STATE.FILLED
		_event_case = 2
		__sent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__receive.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__log.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__reply.value = Reply.new()
		return __reply.value
	
	var __sent: PBField
	func has_sent() -> bool:
		return data[3].state == PB_SERVICE_STATE.FILLED
	func get_sent() -> Sent:
		return __sent.value
	func clear_sent() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__sent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_sent() -> Sent:
		__request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__reply.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		_event_case = 3
		__receive.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__log.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__sent.value = Sent.new()
		return __sent.value
	
	var __receive: PBField
	func has_receive() -> bool:
		return data[4].state == PB_SERVICE_STATE.FILLED
	func get_receive() -> Receive:
		return __receive.value
	func clear_receive() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__receive.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_receive() -> Receive:
		__request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__reply.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__sent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		_event_case = 4
		__log.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__receive.value = Receive.new()
		return __receive.value
	
	var __log: PBField
	func has_log() -> bool:
		return data[5].state == PB_SERVICE_STATE.FILLED
	func get_log() -> Log:
		return __log.value
	func clear_log() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__log.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_log() -> Log:
		__request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__reply.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__sent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__receive.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		_event_case = 5
		__log.value = Log.new()
		return __log.value
	
	func get_event_case() -> int:
		return _event_case
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Request:
	func _init():
		var service
		
		__seq = PBField.new("seq", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __seq
		data[__seq.tag] = service
		
		__get_version = PBField.new("get_version", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __get_version
		data[__get_version.tag] = service
		
		__send = PBField.new("send", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __send
		service.func_ref = Callable(self, "new_send")
		data[__send.tag] = service
		
		__add_peer = PBField.new("add_peer", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __add_peer
		service.func_ref = Callable(self, "new_add_peer")
		data[__add_peer.tag] = service
		
		__del_peer = PBField.new("del_peer", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __del_peer
		data[__del_peer.tag] = service
		
		__mod_peer = PBField.new("mod_peer", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __mod_peer
		service.func_ref = Callable(self, "new_mod_peer")
		data[__mod_peer.tag] = service
		
		__get_peer = PBField.new("get_peer", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __get_peer
		data[__get_peer.tag] = service
		
		__fetch_peers = PBField.new("fetch_peers", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __fetch_peers
		data[__fetch_peers.tag] = service
		
		__set_pmk = PBField.new("set_pmk", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __set_pmk
		data[__set_pmk.tag] = service
		
		__get_mac_address = PBField.new("get_mac_address", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __get_mac_address
		data[__get_mac_address.tag] = service
		
		__is_ready = PBField.new("is_ready", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_ready
		data[__is_ready.tag] = service
		
	var data = {}
	
	enum CommandCase {
		COMMAND_NOT_SET = 0,
		GET_VERSION = 4,
		SEND = 5,
		ADD_PEER = 6,
		DEL_PEER = 7,
		MOD_PEER = 8,
		GET_PEER = 9,
		FETCH_PEERS = 11,
		SET_PMK = 14,
		GET_MAC_ADDRESS = 20,
		IS_READY = 21,
	}
	var _command_case: int = 0

	var __seq: PBField
	func has_seq() -> bool:
		if __seq.value != null:
			return true
		return false
	func get_seq() -> int:
		return __seq.value
	func clear_seq() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__seq.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_seq(value : int) -> void:
		__seq.value = value
	
	var __get_version: PBField
	func has_get_version() -> bool:
		return data[4].state == PB_SERVICE_STATE.FILLED
	func get_get_version() -> bool:
		return __get_version.value
	func clear_get_version() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_get_version(value : bool) -> void:
		data[4].state = PB_SERVICE_STATE.FILLED
		_command_case = 4
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__get_version.value = value
	
	var __send: PBField
	func has_send() -> bool:
		return data[5].state == PB_SERVICE_STATE.FILLED
	func get_send() -> SendData:
		return __send.value
	func clear_send() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_send() -> SendData:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		_command_case = 5
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__send.value = SendData.new()
		return __send.value
	
	var __add_peer: PBField
	func has_add_peer() -> bool:
		return data[6].state == PB_SERVICE_STATE.FILLED
	func get_add_peer() -> Peer:
		return __add_peer.value
	func clear_add_peer() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_add_peer() -> Peer:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		_command_case = 6
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = Peer.new()
		return __add_peer.value
	
	var __del_peer: PBField
	func has_del_peer() -> bool:
		return data[7].state == PB_SERVICE_STATE.FILLED
	func get_del_peer() -> PackedByteArray:
		return __del_peer.value
	func clear_del_peer() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_del_peer(value : PackedByteArray) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		_command_case = 7
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = value
	
	var __mod_peer: PBField
	func has_mod_peer() -> bool:
		return data[8].state == PB_SERVICE_STATE.FILLED
	func get_mod_peer() -> Peer:
		return __mod_peer.value
	func clear_mod_peer() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_mod_peer() -> Peer:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		_command_case = 8
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = Peer.new()
		return __mod_peer.value
	
	var __get_peer: PBField
	func has_get_peer() -> bool:
		return data[9].state == PB_SERVICE_STATE.FILLED
	func get_get_peer() -> PackedByteArray:
		return __get_peer.value
	func clear_get_peer() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_get_peer(value : PackedByteArray) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		_command_case = 9
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = value
	
	var __fetch_peers: PBField
	func has_fetch_peers() -> bool:
		return data[11].state == PB_SERVICE_STATE.FILLED
	func get_fetch_peers() -> bool:
		return __fetch_peers.value
	func clear_fetch_peers() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_fetch_peers(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		data[11].state = PB_SERVICE_STATE.FILLED
		_command_case = 11
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = value
	
	var __set_pmk: PBField
	func has_set_pmk() -> bool:
		return data[14].state == PB_SERVICE_STATE.FILLED
	func get_set_pmk() -> PackedByteArray:
		return __set_pmk.value
	func clear_set_pmk() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_set_pmk(value : PackedByteArray) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		data[14].state = PB_SERVICE_STATE.FILLED
		_command_case = 14
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = value
	
	var __get_mac_address: PBField
	func has_get_mac_address() -> bool:
		return data[20].state == PB_SERVICE_STATE.FILLED
	func get_get_mac_address() -> bool:
		return __get_mac_address.value
	func clear_get_mac_address() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_get_mac_address(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		data[20].state = PB_SERVICE_STATE.FILLED
		_command_case = 20
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = value
	
	var __is_ready: PBField
	func has_is_ready() -> bool:
		return data[21].state == PB_SERVICE_STATE.FILLED
	func get_is_ready() -> bool:
		return __is_ready.value
	func clear_is_ready() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_ready(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		data[21].state = PB_SERVICE_STATE.FILLED
		_command_case = 21
		__is_ready.value = value
	
	func get_command_case() -> int:
		return _command_case
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SendData:
	func _init():
		var service
		
		__peer_addr = PBField.new("peer_addr", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __peer_addr
		data[__peer_addr.tag] = service
		
		__data = PBField.new("data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __data
		data[__data.tag] = service
		
	var data = {}
	
	var __peer_addr: PBField
	func has_peer_addr() -> bool:
		if __peer_addr.value != null:
			return true
		return false
	func get_peer_addr() -> PackedByteArray:
		return __peer_addr.value
	func clear_peer_addr() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__peer_addr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_peer_addr(value : PackedByteArray) -> void:
		__peer_addr.value = value
	
	var __data: PBField
	func has_data() -> bool:
		if __data.value != null:
			return true
		return false
	func get_data() -> PackedByteArray:
		return __data.value
	func clear_data() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_data(value : PackedByteArray) -> void:
		__data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Peer:
	func _init():
		var service
		
		__peer_addr = PBField.new("peer_addr", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __peer_addr
		data[__peer_addr.tag] = service
		
		__lmk = PBField.new("lmk", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __lmk
		data[__lmk.tag] = service
		
		__channel = PBField.new("channel", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __channel
		data[__channel.tag] = service
		
		__ifidx = PBField.new("ifidx", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ifidx
		data[__ifidx.tag] = service
		
		__encrypt = PBField.new("encrypt", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __encrypt
		data[__encrypt.tag] = service
		
	var data = {}
	
	var __peer_addr: PBField
	func has_peer_addr() -> bool:
		if __peer_addr.value != null:
			return true
		return false
	func get_peer_addr() -> PackedByteArray:
		return __peer_addr.value
	func clear_peer_addr() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__peer_addr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_peer_addr(value : PackedByteArray) -> void:
		__peer_addr.value = value
	
	var __lmk: PBField
	func has_lmk() -> bool:
		if __lmk.value != null:
			return true
		return false
	func get_lmk() -> PackedByteArray:
		return __lmk.value
	func clear_lmk() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__lmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_lmk(value : PackedByteArray) -> void:
		__lmk.value = value
	
	var __channel: PBField
	func has_channel() -> bool:
		if __channel.value != null:
			return true
		return false
	func get_channel() -> int:
		return __channel.value
	func clear_channel() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__channel.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_channel(value : int) -> void:
		__channel.value = value
	
	var __ifidx: PBField
	func has_ifidx() -> bool:
		if __ifidx.value != null:
			return true
		return false
	func get_ifidx() -> int:
		return __ifidx.value
	func clear_ifidx() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__ifidx.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ifidx(value : int) -> void:
		__ifidx.value = value
	
	var __encrypt: PBField
	func has_encrypt() -> bool:
		if __encrypt.value != null:
			return true
		return false
	func get_encrypt() -> bool:
		return __encrypt.value
	func clear_encrypt() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__encrypt.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_encrypt(value : bool) -> void:
		__encrypt.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SwitchChannelConfig:
	func _init():
		var service
		
		__type = PBField.new("type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __type
		data[__type.tag] = service
		
		__channel = PBField.new("channel", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __channel
		data[__channel.tag] = service
		
		__sec_channel = PBField.new("sec_channel", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __sec_channel
		data[__sec_channel.tag] = service
		
		__wait_time_ms = PBField.new("wait_time_ms", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __wait_time_ms
		data[__wait_time_ms.tag] = service
		
		__op_id = PBField.new("op_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __op_id
		data[__op_id.tag] = service
		
		__dest_mac = PBField.new("dest_mac", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __dest_mac
		data[__dest_mac.tag] = service
		
	var data = {}
	
	var __type: PBField
	func has_type() -> bool:
		if __type.value != null:
			return true
		return false
	func get_type() -> int:
		return __type.value
	func clear_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_type(value : int) -> void:
		__type.value = value
	
	var __channel: PBField
	func has_channel() -> bool:
		if __channel.value != null:
			return true
		return false
	func get_channel() -> int:
		return __channel.value
	func clear_channel() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__channel.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_channel(value : int) -> void:
		__channel.value = value
	
	var __sec_channel: PBField
	func has_sec_channel() -> bool:
		if __sec_channel.value != null:
			return true
		return false
	func get_sec_channel() -> int:
		return __sec_channel.value
	func clear_sec_channel() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__sec_channel.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_sec_channel(value : int) -> void:
		__sec_channel.value = value
	
	var __wait_time_ms: PBField
	func has_wait_time_ms() -> bool:
		if __wait_time_ms.value != null:
			return true
		return false
	func get_wait_time_ms() -> int:
		return __wait_time_ms.value
	func clear_wait_time_ms() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__wait_time_ms.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_wait_time_ms(value : int) -> void:
		__wait_time_ms.value = value
	
	var __op_id: PBField
	func has_op_id() -> bool:
		if __op_id.value != null:
			return true
		return false
	func get_op_id() -> int:
		return __op_id.value
	func clear_op_id() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__op_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_op_id(value : int) -> void:
		__op_id.value = value
	
	var __dest_mac: PBField
	func has_dest_mac() -> bool:
		if __dest_mac.value != null:
			return true
		return false
	func get_dest_mac() -> PackedByteArray:
		return __dest_mac.value
	func clear_dest_mac() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__dest_mac.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_dest_mac(value : PackedByteArray) -> void:
		__dest_mac.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RemainOnChannelConfig:
	func _init():
		var service
		
		__type = PBField.new("type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __type
		data[__type.tag] = service
		
		__channel = PBField.new("channel", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __channel
		data[__channel.tag] = service
		
		__sec_channel = PBField.new("sec_channel", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __sec_channel
		data[__sec_channel.tag] = service
		
		__wait_time_ms = PBField.new("wait_time_ms", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __wait_time_ms
		data[__wait_time_ms.tag] = service
		
		__op_id = PBField.new("op_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __op_id
		data[__op_id.tag] = service
		
	var data = {}
	
	var __type: PBField
	func has_type() -> bool:
		if __type.value != null:
			return true
		return false
	func get_type() -> int:
		return __type.value
	func clear_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_type(value : int) -> void:
		__type.value = value
	
	var __channel: PBField
	func has_channel() -> bool:
		if __channel.value != null:
			return true
		return false
	func get_channel() -> int:
		return __channel.value
	func clear_channel() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__channel.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_channel(value : int) -> void:
		__channel.value = value
	
	var __sec_channel: PBField
	func has_sec_channel() -> bool:
		if __sec_channel.value != null:
			return true
		return false
	func get_sec_channel() -> int:
		return __sec_channel.value
	func clear_sec_channel() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__sec_channel.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_sec_channel(value : int) -> void:
		__sec_channel.value = value
	
	var __wait_time_ms: PBField
	func has_wait_time_ms() -> bool:
		if __wait_time_ms.value != null:
			return true
		return false
	func get_wait_time_ms() -> int:
		return __wait_time_ms.value
	func clear_wait_time_ms() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__wait_time_ms.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_wait_time_ms(value : int) -> void:
		__wait_time_ms.value = value
	
	var __op_id: PBField
	func has_op_id() -> bool:
		if __op_id.value != null:
			return true
		return false
	func get_op_id() -> int:
		return __op_id.value
	func clear_op_id() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__op_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_op_id(value : int) -> void:
		__op_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RateConfig:
	func _init():
		var service
		
		__phymod = PBField.new("phymod", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __phymod
		data[__phymod.tag] = service
		
		__rate = PBField.new("rate", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __rate
		data[__rate.tag] = service
		
		__ersu = PBField.new("ersu", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __ersu
		data[__ersu.tag] = service
		
		__dcm = PBField.new("dcm", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __dcm
		data[__dcm.tag] = service
		
	var data = {}
	
	var __phymod: PBField
	func has_phymod() -> bool:
		if __phymod.value != null:
			return true
		return false
	func get_phymod() -> int:
		return __phymod.value
	func clear_phymod() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__phymod.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_phymod(value : int) -> void:
		__phymod.value = value
	
	var __rate: PBField
	func has_rate() -> bool:
		if __rate.value != null:
			return true
		return false
	func get_rate() -> int:
		return __rate.value
	func clear_rate() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__rate.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_rate(value : int) -> void:
		__rate.value = value
	
	var __ersu: PBField
	func has_ersu() -> bool:
		if __ersu.value != null:
			return true
		return false
	func get_ersu() -> bool:
		return __ersu.value
	func clear_ersu() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ersu.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_ersu(value : bool) -> void:
		__ersu.value = value
	
	var __dcm: PBField
	func has_dcm() -> bool:
		if __dcm.value != null:
			return true
		return false
	func get_dcm() -> bool:
		return __dcm.value
	func clear_dcm() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__dcm.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_dcm(value : bool) -> void:
		__dcm.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Reply:
	func _init():
		var service
		
		__seq = PBField.new("seq", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __seq
		data[__seq.tag] = service
		
		__status = PBField.new("status", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __status
		data[__status.tag] = service
		
		__get_version = PBField.new("get_version", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __get_version
		data[__get_version.tag] = service
		
		__send = PBField.new("send", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __send
		data[__send.tag] = service
		
		__add_peer = PBField.new("add_peer", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __add_peer
		data[__add_peer.tag] = service
		
		__del_peer = PBField.new("del_peer", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __del_peer
		data[__del_peer.tag] = service
		
		__mod_peer = PBField.new("mod_peer", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __mod_peer
		data[__mod_peer.tag] = service
		
		__get_peer = PBField.new("get_peer", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __get_peer
		service.func_ref = Callable(self, "new_get_peer")
		data[__get_peer.tag] = service
		
		__fetch_peers = PBField.new("fetch_peers", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __fetch_peers
		service.func_ref = Callable(self, "new_fetch_peers")
		data[__fetch_peers.tag] = service
		
		__set_pmk = PBField.new("set_pmk", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __set_pmk
		data[__set_pmk.tag] = service
		
		__get_mac_address = PBField.new("get_mac_address", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __get_mac_address
		data[__get_mac_address.tag] = service
		
		__is_ready = PBField.new("is_ready", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_ready
		data[__is_ready.tag] = service
		
	var data = {}
	
	enum CommandCase {
		COMMAND_NOT_SET = 0,
		GET_VERSION = 4,
		SEND = 5,
		ADD_PEER = 6,
		DEL_PEER = 7,
		MOD_PEER = 8,
		GET_PEER = 9,
		FETCH_PEERS = 11,
		SET_PMK = 14,
		GET_MAC_ADDRESS = 20,
		IS_READY = 21,
	}
	var _command_case: int = 0

	var __seq: PBField
	func has_seq() -> bool:
		if __seq.value != null:
			return true
		return false
	func get_seq() -> int:
		return __seq.value
	func clear_seq() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__seq.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_seq(value : int) -> void:
		__seq.value = value
	
	var __status: PBField
	func has_status() -> bool:
		if __status.value != null:
			return true
		return false
	func get_status():
		return __status.value
	func clear_status() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_status(value) -> void:
		__status.value = value
	
	var __get_version: PBField
	func has_get_version() -> bool:
		return data[4].state == PB_SERVICE_STATE.FILLED
	func get_get_version() -> int:
		return __get_version.value
	func clear_get_version() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_get_version(value : int) -> void:
		data[4].state = PB_SERVICE_STATE.FILLED
		_command_case = 4
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__get_version.value = value
	
	var __send: PBField
	func has_send() -> bool:
		return data[5].state == PB_SERVICE_STATE.FILLED
	func get_send() -> bool:
		return __send.value
	func clear_send() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_send(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		_command_case = 5
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__send.value = value
	
	var __add_peer: PBField
	func has_add_peer() -> bool:
		return data[6].state == PB_SERVICE_STATE.FILLED
	func get_add_peer() -> bool:
		return __add_peer.value
	func clear_add_peer() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_add_peer(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		_command_case = 6
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = value
	
	var __del_peer: PBField
	func has_del_peer() -> bool:
		return data[7].state == PB_SERVICE_STATE.FILLED
	func get_del_peer() -> bool:
		return __del_peer.value
	func clear_del_peer() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_del_peer(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		_command_case = 7
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = value
	
	var __mod_peer: PBField
	func has_mod_peer() -> bool:
		return data[8].state == PB_SERVICE_STATE.FILLED
	func get_mod_peer() -> bool:
		return __mod_peer.value
	func clear_mod_peer() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_mod_peer(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		_command_case = 8
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = value
	
	var __get_peer: PBField
	func has_get_peer() -> bool:
		return data[9].state == PB_SERVICE_STATE.FILLED
	func get_get_peer() -> Peer:
		return __get_peer.value
	func clear_get_peer() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_get_peer() -> Peer:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		_command_case = 9
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = Peer.new()
		return __get_peer.value
	
	var __fetch_peers: PBField
	func has_fetch_peers() -> bool:
		return data[11].state == PB_SERVICE_STATE.FILLED
	func get_fetch_peers() -> FetchPeersResult:
		return __fetch_peers.value
	func clear_fetch_peers() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_fetch_peers() -> FetchPeersResult:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		data[11].state = PB_SERVICE_STATE.FILLED
		_command_case = 11
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = FetchPeersResult.new()
		return __fetch_peers.value
	
	var __set_pmk: PBField
	func has_set_pmk() -> bool:
		return data[14].state == PB_SERVICE_STATE.FILLED
	func get_set_pmk() -> bool:
		return __set_pmk.value
	func clear_set_pmk() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_set_pmk(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		data[14].state = PB_SERVICE_STATE.FILLED
		_command_case = 14
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = value
	
	var __get_mac_address: PBField
	func has_get_mac_address() -> bool:
		return data[20].state == PB_SERVICE_STATE.FILLED
	func get_get_mac_address() -> PackedByteArray:
		return __get_mac_address.value
	func clear_get_mac_address() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_get_mac_address(value : PackedByteArray) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		data[20].state = PB_SERVICE_STATE.FILLED
		_command_case = 20
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = value
	
	var __is_ready: PBField
	func has_is_ready() -> bool:
		return data[21].state == PB_SERVICE_STATE.FILLED
	func get_is_ready() -> bool:
		return __is_ready.value
	func clear_is_ready() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_command_case = 0
		__is_ready.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_ready(value : bool) -> void:
		__get_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__send.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__add_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__del_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mod_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__get_peer.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__fetch_peers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__set_pmk.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__get_mac_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		data[21].state = PB_SERVICE_STATE.FILLED
		_command_case = 21
		__is_ready.value = value
	
	func get_command_case() -> int:
		return _command_case
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class FetchPeersResult:
	func _init():
		var service
		
		var __peers_default: Array[Peer] = []
		__peers = PBField.new("peers", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __peers_default)
		service = PBServiceField.new()
		service.field = __peers
		service.func_ref = Callable(self, "add_peers")
		data[__peers.tag] = service
		
	var data = {}
	
	var __peers: PBField
	func get_peers() -> Array[Peer]:
		return __peers.value
	func clear_peers() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__peers.value.clear()
	func add_peers() -> Peer:
		var element = Peer.new()
		__peers.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Sent:
	func _init():
		var service
		
		__src_addr = PBField.new("src_addr", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __src_addr
		data[__src_addr.tag] = service
		
		__des_addr = PBField.new("des_addr", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __des_addr
		data[__des_addr.tag] = service
		
		__status = PBField.new("status", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __status
		data[__status.tag] = service
		
	var data = {}
	
	var __src_addr: PBField
	func has_src_addr() -> bool:
		if __src_addr.value != null:
			return true
		return false
	func get_src_addr() -> PackedByteArray:
		return __src_addr.value
	func clear_src_addr() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__src_addr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_src_addr(value : PackedByteArray) -> void:
		__src_addr.value = value
	
	var __des_addr: PBField
	func has_des_addr() -> bool:
		if __des_addr.value != null:
			return true
		return false
	func get_des_addr() -> PackedByteArray:
		return __des_addr.value
	func clear_des_addr() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__des_addr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_des_addr(value : PackedByteArray) -> void:
		__des_addr.value = value
	
	var __status: PBField
	func has_status() -> bool:
		if __status.value != null:
			return true
		return false
	func get_status():
		return __status.value
	func clear_status() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_status(value) -> void:
		__status.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Receive:
	func _init():
		var service
		
		__src_addr = PBField.new("src_addr", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __src_addr
		data[__src_addr.tag] = service
		
		__data = PBField.new("data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __data
		data[__data.tag] = service
		
	var data = {}
	
	var __src_addr: PBField
	func has_src_addr() -> bool:
		if __src_addr.value != null:
			return true
		return false
	func get_src_addr() -> PackedByteArray:
		return __src_addr.value
	func clear_src_addr() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__src_addr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_src_addr(value : PackedByteArray) -> void:
		__src_addr.value = value
	
	var __data: PBField
	func has_data() -> bool:
		if __data.value != null:
			return true
		return false
	func get_data() -> PackedByteArray:
		return __data.value
	func clear_data() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_data(value : PackedByteArray) -> void:
		__data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Log:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
