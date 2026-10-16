-- qvariant.lua
-- Pure-Lua Qt QDataStream / QVariantMap binary decoder, byte-exact encoder,
-- and Kobo Event.Checksum (MD5 + "kobo.rules") calculator.

local bit = require("bit")
local band, bor, bxor, lshift, rshift, rol = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift, bit.rol

local QVariant = {}

-- Try KOReader's built-in ffi/sha2.md5 first; provide pure-LuaJIT MD5 fallback for standalone testing
local ok_sha2, sha2 = pcall(require, "ffi/sha2")
local native_md5 = ok_sha2 and type(sha2) == "table" and sha2.md5 or nil

-- Pure LuaJIT MD5 implementation (RFC 1321) used if ffi/sha2 is not in package.path
local md5_k = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
}
local md5_s = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
}

local function fallback_md5(msg)
    local len = #msg
    local bit_len = len * 8
    local pad_len = (56 - (len + 1) % 64) % 64
    local low_bits = bit_len % 4294967296
    local high_bits = math.floor(bit_len / 4294967296)
    local function le32_bytes(v)
        local b1 = v % 256; v = math.floor(v / 256)
        local b2 = v % 256; v = math.floor(v / 256)
        local b3 = v % 256; v = math.floor(v / 256)
        local b4 = v % 256
        return string.char(b1, b2, b3, b4)
    end
    local padded = msg .. "\128" .. string.rep("\0", pad_len) .. le32_bytes(low_bits) .. le32_bytes(high_bits)
    local a0, b0, c0, d0 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
    local X = {}
    for offset = 1, #padded, 64 do
        for i = 0, 15 do
            local p = offset + i * 4
            local c1, c2, c3, c4 = string.byte(padded, p, p + 3)
            X[i] = bor(c1, lshift(c2, 8), lshift(c3, 16), lshift(c4, 24))
        end
        local A, B, C, D = a0, b0, c0, d0
        for i = 0, 63 do
            local F, g
            if i < 16 then
                F = bor(band(B, C), band( bit.bnot(B), D ))
                g = i
            elseif i < 32 then
                F = bor(band(D, B), band( bit.bnot(D), C ))
                g = (5 * i + 1) % 16
            elseif i < 48 then
                F = bxor(B, C, D)
                g = (3 * i + 5) % 16
            else
                F = bxor(C, bor(B, bit.bnot(D)))
                g = (7 * i) % 16
            end
            local temp = D
            D = C
            C = B
            local sum = bit.tobit(A + F + md5_k[i + 1] + X[g])
            B = bit.tobit(B + rol(sum, md5_s[i + 1]))
            A = temp
        end
        a0 = bit.tobit(a0 + A)
        b0 = bit.tobit(b0 + B)
        c0 = bit.tobit(c0 + C)
        d0 = bit.tobit(d0 + D)
    end
    local function to_le_hex(v)
        local u = v < 0 and (v + 4294967296) or v
        local b1 = u % 256; u = math.floor(u / 256)
        local b2 = u % 256; u = math.floor(u / 256)
        local b3 = u % 256; u = math.floor(u / 256)
        local b4 = u % 256
        return string.format("%02x%02x%02x%02x", b1, b2, b3, b4)
    end
    return to_le_hex(a0) .. to_le_hex(b0) .. to_le_hex(c0) .. to_le_hex(d0)
end

function QVariant.md5(str)
    if native_md5 then
        return native_md5(str)
    end
    return fallback_md5(str)
end

-- Hex <-> Raw Bytes helpers
function QVariant.hex_to_bytes(hex)
    if not hex or hex == "" then return "" end
    return (hex:gsub("(%x%x)", function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

function QVariant.bytes_to_hex(bytes)
    if not bytes or bytes == "" then return "" end
    local out = {}
    for i = 1, #bytes do
        out[i] = string.format("%02X", string.byte(bytes, i))
    end
    return table.concat(out)
end

-- UTF-16BE <-> UTF-8 conversion
local function utf16be_to_utf8(bytes)
    local out = {}
    local i = 1
    local n = #bytes
    while i <= n - 1 do
        local hi, lo = string.byte(bytes, i, i + 1)
        i = i + 2
        local cp = hi * 256 + lo
        if cp >= 0xD800 and cp <= 0xDBFF and i <= n - 1 then
            local hi2, lo2 = string.byte(bytes, i, i + 1)
            local cp2 = hi2 * 256 + lo2
            if cp2 >= 0xDC00 and cp2 <= 0xDFFF then
                i = i + 2
                cp = 0x10000 + (cp - 0xD800) * 0x400 + (cp2 - 0xDC00)
            end
        end
        if cp < 0x80 then
            out[#out + 1] = string.char(cp)
        elseif cp < 0x800 then
            out[#out + 1] = string.char(
                0xC0 + math.floor(cp / 64),
                0x80 + (cp % 64)
            )
        elseif cp < 0x10000 then
            out[#out + 1] = string.char(
                0xE0 + math.floor(cp / 4096),
                0x80 + (math.floor(cp / 64) % 64),
                0x80 + (cp % 64)
            )
        else
            out[#out + 1] = string.char(
                0xF0 + math.floor(cp / 262144),
                0x80 + (math.floor(cp / 4096) % 64),
                0x80 + (math.floor(cp / 64) % 64),
                0x80 + (cp % 64)
            )
        end
    end
    return table.concat(out)
end

local function utf8_to_utf16be(str)
    local out = {}
    local i = 1
    local n = #str
    while i <= n do
        local b1 = string.byte(str, i)
        local cp
        if b1 < 0x80 then
            cp = b1
            i = i + 1
        elseif b1 < 0xE0 then
            local b2 = string.byte(str, i + 1) or 0x80
            cp = (b1 - 0xC0) * 64 + (b2 - 0x80)
            i = i + 2
        elseif b1 < 0xF0 then
            local b2 = string.byte(str, i + 1) or 0x80
            local b3 = string.byte(str, i + 2) or 0x80
            cp = (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80)
            i = i + 3
        else
            local b2 = string.byte(str, i + 1) or 0x80
            local b3 = string.byte(str, i + 2) or 0x80
            local b4 = string.byte(str, i + 3) or 0x80
            cp = (b1 - 0xF0) * 262144 + (b2 - 0x80) * 4096 + (b3 - 0x80) * 64 + (b4 - 0x80)
            i = i + 4
        end
        if cp < 0x10000 then
            out[#out + 1] = string.char(math.floor(cp / 256), cp % 256)
        else
            cp = cp - 0x10000
            local w1 = 0xD800 + math.floor(cp / 0x400)
            local w2 = 0xDC00 + (cp % 0x400)
            out[#out + 1] = string.char(math.floor(w1 / 256), w1 % 256, math.floor(w2 / 256), w2 % 256)
        end
    end
    return table.concat(out)
end

-- Big-endian primitive readers & writers
local function read_u32(data, pos)
    local b1, b2, b3, b4 = string.byte(data, pos, pos + 3)
    if not b4 then error("QVariant: unexpected EOF reading u32 at " .. tostring(pos)) end
    return ((b1 * 256 + b2) * 256 + b3) * 256 + b4, pos + 4
end

local function read_i32(data, pos)
    local u, next_pos = read_u32(data, pos)
    if u >= 2147483648 then u = u - 4294967296 end
    return u, next_pos
end

local function read_u8(data, pos)
    local b = string.byte(data, pos)
    if not b then error("QVariant: unexpected EOF reading u8 at " .. tostring(pos)) end
    return b, pos + 1
end

local function read_qstring(data, pos)
    local len
    len, pos = read_u32(data, pos)
    if len == 4294967295 then
        return nil, pos
    end
    if len == 0 then
        return "", pos
    end
    local sub = data:sub(pos, pos + len - 1)
    if #sub < len then error("QVariant: unexpected EOF reading QString") end
    return utf16be_to_utf8(sub), pos + len
end

local function read_qbytearray(data, pos)
    local len
    len, pos = read_u32(data, pos)
    if len == 4294967295 then
        return nil, pos
    end
    if len == 0 then
        return "", pos
    end
    local sub = data:sub(pos, pos + len - 1)
    if #sub < len then error("QVariant: unexpected EOF reading QByteArray") end
    return sub, pos + len
end

local function write_u32(u)
    if u < 0 then u = u + 4294967296 end
    local b4 = u % 256; u = math.floor(u / 256)
    local b3 = u % 256; u = math.floor(u / 256)
    local b2 = u % 256; u = math.floor(u / 256)
    local b1 = u % 256
    return string.char(b1, b2, b3, b4)
end

local function write_i32(v)
    if v < 0 then v = v + 4294967296 end
    return write_u32(v)
end

local function write_u8(v)
    return string.char(v % 256)
end

local function write_qstring(s)
    if s == nil then
        return "\255\255\255\255"
    end
    local u16 = utf8_to_utf16be(s)
    return write_u32(#u16) .. u16
end

local function write_qbytearray(b)
    if b == nil then
        return "\255\255\255\255"
    end
    return write_u32(#b) .. b
end

-- Decode a QVariantMap binary blob into an AST that preserves exact Qt types,
-- AND a plain Lua table for easy manipulation.
-- AST node format: { _qv_type = <string>, _is_null = <0|1>, value = <any> }
local read_variant_ast, read_map_ast

read_variant_ast = function(data, pos)
    local vtype, is_null
    vtype, pos = read_u32(data, pos)
    is_null, pos = read_u8(data, pos)
    if vtype == 0 then
        local s
        s, pos = read_qstring(data, pos)
        return { _qv_type = "Invalid", _is_null = is_null, value = s }, pos
    elseif vtype == 1 then
        local b
        b, pos = read_u8(data, pos)
        return { _qv_type = "bool", _is_null = is_null, value = (b ~= 0) }, pos
    elseif vtype == 2 then
        local v
        v, pos = read_i32(data, pos)
        return { _qv_type = "int", _is_null = is_null, value = v }, pos
    elseif vtype == 3 then
        local v
        v, pos = read_u32(data, pos)
        return { _qv_type = "uint", _is_null = is_null, value = v }, pos
    elseif vtype == 4 or vtype == 5 then
        local hi, lo
        hi, pos = read_u32(data, pos)
        lo, pos = read_u32(data, pos)
        return { _qv_type = (vtype == 4 and "int64" or "uint64"), _is_null = is_null, value = hi * 4294967296 + lo }, pos
    elseif vtype == 8 then
        local m
        m, pos = read_map_ast(data, pos)
        return { _qv_type = "QVariantMap", _is_null = is_null, value = m }, pos
    elseif vtype == 9 then
        local count
        count, pos = read_u32(data, pos)
        local list = {}
        for i = 1, count do
            list[i], pos = read_variant_ast(data, pos)
        end
        return { _qv_type = "QVariantList", _is_null = is_null, value = list }, pos
    elseif vtype == 10 then
        local s
        s, pos = read_qstring(data, pos)
        return { _qv_type = "QString", _is_null = is_null, value = s }, pos
    elseif vtype == 12 then
        local b
        b, pos = read_qbytearray(data, pos)
        return { _qv_type = "QByteArray", _is_null = is_null, value = b }, pos
    else
        error("QVariant: unsupported Qt type id " .. tostring(vtype))
    end
end

read_map_ast = function(data, pos)
    local count
    count, pos = read_u32(data, pos)
    local map = {}
    for _ = 1, count do
        local k, v
        k, pos = read_qstring(data, pos)
        v, pos = read_variant_ast(data, pos)
        map[k] = v
    end
    return map, pos
end

function QVariant.decode_ast(data)
    if not data or #data == 0 then return {} end
    local ast, pos = read_map_ast(data, 1)
    if pos - 1 ~= #data then
        error(string.format("QVariant: trailing bytes (%d != %d)", pos - 1, #data))
    end
    return ast
end

local function ast_to_plain(node)
    if type(node) ~= "table" or not node._qv_type then
        return node
    end
    local t = node._qv_type
    if t == "Invalid" then
        return nil
    elseif t == "QVariantMap" then
        local res = {}
        for k, v in pairs(node.value) do
            res[k] = ast_to_plain(v)
        end
        return res
    elseif t == "QVariantList" then
        local res = {}
        for i = 1, #node.value do
            res[i] = ast_to_plain(node.value[i])
        end
        return res
    else
        return node.value
    end
end

function QVariant.decode(data)
    if not data or #data == 0 then return {}, {} end
    local ast = QVariant.decode_ast(data)
    local plain = {}
    for k, v in pairs(ast) do
        plain[k] = ast_to_plain(v)
    end
    return plain, ast
end

-- Encode AST back into byte-exact Qt QDataStream QVariantMap binary format.
-- Note: Qt QMap serializes keys in reverse UTF-16 code unit order.
local write_variant_ast, write_map_ast

local TYPE_IDS = {
    Invalid = 0,
    bool = 1,
    int = 2,
    uint = 3,
    int64 = 4,
    uint64 = 5,
    QVariantMap = 8,
    QVariantList = 9,
    QString = 10,
    QByteArray = 12,
}

write_variant_ast = function(node)
    local t = node._qv_type
    local tid = TYPE_IDS[t]
    if not tid then error("QVariant: unknown AST type " .. tostring(t)) end
    local is_null = node._is_null or 0
    local header = write_u32(tid) .. write_u8(is_null)
    if t == "Invalid" or t == "QString" then
        return header .. write_qstring(node.value)
    elseif t == "QByteArray" then
        return header .. write_qbytearray(node.value)
    elseif t == "bool" then
        return header .. write_u8(node.value and 1 or 0)
    elseif t == "int" then
        return header .. write_i32(node.value or 0)
    elseif t == "uint" then
        return header .. write_u32(node.value or 0)
    elseif t == "int64" or t == "uint64" then
        local v = node.value or 0
        local hi = math.floor(v / 4294967296)
        local lo = v % 4294967296
        return header .. write_u32(hi) .. write_u32(lo)
    elseif t == "QVariantMap" then
        return header .. write_map_ast(node.value)
    elseif t == "QVariantList" then
        local parts = { header, write_u32(#node.value) }
        for i = 1, #node.value do
            parts[#parts + 1] = write_variant_ast(node.value[i])
        end
        return table.concat(parts)
    end
end

write_map_ast = function(map_ast)
    local keys = {}
    for k, _ in pairs(map_ast) do
        keys[#keys + 1] = k
    end
    -- Reverse UTF-16BE order (identical to reverse byte order on UTF-16BE strings)
    table.sort(keys, function(a, b)
        return utf8_to_utf16be(a) > utf8_to_utf16be(b)
    end)
    local parts = { write_u32(#keys) }
    for i = 1, #keys do
        local k = keys[i]
        parts[#parts + 1] = write_qstring(k)
        parts[#parts + 1] = write_variant_ast(map_ast[k])
    end
    return table.concat(parts)
end

function QVariant.encode_ast(map_ast)
    return write_map_ast(map_ast)
end

-- Helper constructors for AST nodes when building or updating Kobo Event ExtraData
function QVariant.qint(v)
    return { _qv_type = "int", _is_null = 0, value = math.floor(tonumber(v) or 0) }
end

function QVariant.qbool(v)
    return { _qv_type = "bool", _is_null = 0, value = v and true or false }
end

function QVariant.qstring(s)
    return { _qv_type = "QString", _is_null = (s == nil and 1 or 0), value = s }
end

function QVariant.qbytearray(b)
    return { _qv_type = "QByteArray", _is_null = (b == nil and 1 or 0), value = b }
end

function QVariant.qinvalid()
    return { _qv_type = "Invalid", _is_null = 1, value = nil }
end

function QVariant.qint_list(int_array)
    local nodes = {}
    for i = 1, #int_array do
        nodes[i] = QVariant.qint(int_array[i])
    end
    return { _qv_type = "QVariantList", _is_null = 0, value = nodes }
end

function QVariant.qstring_map(tbl)
    local m = {}
    for k, v in pairs(tbl) do
        m[k] = QVariant.qstring(tostring(v))
    end
    return { _qv_type = "QVariantMap", _is_null = 0, value = m }
end

-- Compute Kobo Event.Checksum:
-- md5(ContentID + str(EventCount) + str(EventType) + ExtraData_bytes + FirstOccurrence + LastOccurrence + "kobo.rules")
function QVariant.event_checksum(content_id, event_count, event_type, extra_data_bytes, first_occurrence, last_occurrence)
    local cid = content_id and tostring(content_id) or ""
    local ec = event_count ~= nil and tostring(tonumber(event_count)) or ""
    local et = event_type ~= nil and tostring(tonumber(event_type)) or ""
    local ed = extra_data_bytes or ""
    local fo = first_occurrence and tostring(first_occurrence) or ""
    local lo = last_occurrence and tostring(last_occurrence) or ""
    local payload = cid .. ec .. et .. ed .. fo .. lo .. "kobo.rules"
    return QVariant.md5(payload)
end

return QVariant
