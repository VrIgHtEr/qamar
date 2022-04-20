if jit and jit.opt and jit.opt.start then
	jit.opt.start(3)
	jit.opt.start(
		"maxtrace=10000",
		"hotloop=1",
		"maxmcode=16384",
		"hotexit=1",
		"maxirconst=10000",
		"maxrecord=10000",
		"maxside=10000",
		"maxsnap=10000"
	)
end

local qamar_lexer = _G["qamar_lexer"]
local ffi = require("ffi")
if ffi then
	local setmetatable = setmetatable
	local lexer = setmetatable({}, { __index = qamar_lexer })
	ffi.cdef([[
typedef struct {
  size_t file_char;
  size_t row;
  size_t col;
  size_t byte;
  size_t file_byte;
} qamar_position_t;

typedef struct {
  qamar_position_t left;
  qamar_position_t right;
} qamar_range_t;

typedef struct {
  size_t id;
  int type;
  qamar_range_t pos;
  const char *value;
  size_t len;
} qamar_token_t;

typedef struct {
  size_t index;
  size_t file_char;
  size_t row;
  size_t col;
  size_t byte;
  size_t file_byte;
} qamar_lexer_transaction_t;

typedef struct {
  size_t skip_ws_ctr;
  size_t len;
  qamar_lexer_transaction_t *transactions;
  size_t transactions_capacity;
  size_t transactions_index;
  qamar_lexer_transaction_t t;
  const char data[];
} qamar_lexer_t;

void*malloc(const size_t);
void free(void*);

int lexer_new(qamar_lexer_t *c, const char *, const size_t);
void lexer_destroy(qamar_lexer_t *);
const char *lexer_peek(qamar_lexer_t *, size_t);
const char *lexer_take(qamar_lexer_t *, size_t *);
void lexer_skipws(qamar_lexer_t *);
qamar_position_t lexer_pos(qamar_lexer_t *);
bool lexer_keyword(qamar_lexer_t *, qamar_token_t *);
bool lexer_name(qamar_lexer_t *, qamar_token_t *);
bool lexer_token(qamar_lexer_t *, qamar_token_t *);
]])

	do
		local mt = {
			__metatable = function() end,
			__tostring = function(self)
				return tonumber(self.row) .. ":" .. tonumber(self.col)
			end,
		}
		ffi.metatype(ffi.typeof("qamar_position_t"), mt)
	end

	local token_mt = {
		__metatable = function() end,
		__tostring = function(self)
			return self.value
		end,
	}

	local C = ffi.C
	local slen = string.len
	local qamar_token_t = ffi.typeof("qamar_token_t")
	local qamar_lexer_t = ffi.typeof("qamar_lexer_t")
	local qamar_lexer_tp = ffi.typeof("qamar_lexer_t*")
	local void_tp = ffi.typeof("void*")
	local gc = ffi.gc
	local copy = ffi.copy
	local cast = ffi.cast
	local fstring = ffi.string
	local typesize = ffi.sizeof(qamar_lexer_t)

	local tokenbuf = ffi.new(qamar_token_t)
	local takebuf = ffi.new("size_t[1]")

	local function finalizer(x)
		local _ = C.lexer_destroy(x)
		_ = C.free(cast(void_tp, x))
	end

	function lexer.new(s)
		local len = slen(s)
		local size = len + typesize
		local l = cast(qamar_lexer_tp, C.malloc(size))
		if l ~= nil then
			local ret = C.lexer_new(l, s, len)
			if ret == 0 then
				copy(cast(void_tp, l.data), s, len)
				--io.stdout:write("OLE!!!\n")
				--io.stdout:flush()
				return gc(l, finalizer)
			end
			C.free(cast(void_tp, l))
		end
	end

	function lexer.peek(self, skip)
		local ret = C.lexer_peek(self, skip or 0)
		if ret ~= nil then
			return fstring(ret, 1)
		end
	end

	function lexer.take(self, amt)
		takebuf[0] = amt or 1
		local ret = C.lexer_take(self, takebuf)
		if ret ~= nil then
			return fstring(ret, takebuf[0])
		end
	end

	lexer.skipws = function(self)
		return C.lexer_skipws(self)
	end
	lexer.pos = function(self)
		return C.lexer_pos(self)
	end

	local function create_token(t)
		return setmetatable({
			pos = t.pos,
			type = t.type,
			value = fstring(t.value, t.len),
		}, token_mt)
	end

	function lexer.keyword(self)
		if C.lexer_keyword(self, tokenbuf) then
			return create_token(tokenbuf)
		end
	end

	function lexer.name(self)
		if C.lexer_name(self, tokenbuf) then
			return create_token(tokenbuf)
		end
	end

	function lexer.token(self)
		if C.lexer_token(self, tokenbuf) then
			return create_token(tokenbuf)
		end
	end
	return lexer
end

return qamar_lexer
