local qamar_lexer = _G["qamar_lexer"]
local lexer = setmetatable({}, { __index = qamar_lexer })

local ffi = require("ffi")
if ffi then
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
void lexer_begin(qamar_lexer_t *);
void lexer_undo(qamar_lexer_t *);
void lexer_commit(qamar_lexer_t *);
const char *lexer_try_consume_string(qamar_lexer_t *, const char *, size_t);
void lexer_skipws(qamar_lexer_t *);
void lexer_suspend_skip_ws(qamar_lexer_t *);
void lexer_resume_skip_ws(qamar_lexer_t *);
const char *lexer_numeric(qamar_lexer_t *);
const char *lexer_alpha(qamar_lexer_t *);
const char *lexer_alphanumeric(qamar_lexer_t *);
qamar_position_t lexer_pos(qamar_lexer_t *);
bool lexer_keyword(qamar_lexer_t *, qamar_token_t *);
bool lexer_name(qamar_lexer_t *, qamar_token_t *);
const char *lexer_take(qamar_lexer_t *, size_t *);
]])
	local slen = string.len
	local qamar_token_t = ffi.typeof("qamar_token_t")
	local qamar_lexer_t = ffi.typeof("qamar_lexer_t")
	local qamar_lexer_tp = ffi.typeof("qamar_lexer_t*")
	local void_tp = ffi.typeof("void*")
	local gc = ffi.gc
	local copy = ffi.copy
	local cast = ffi.cast
	local fstring = ffi.string
	local malloc = ffi.C.malloc
	local free = ffi.C.free
	local typesize = ffi.sizeof(qamar_lexer_t)
	local lexer_destroy = ffi.C.lexer_destroy
	local lexer_new = ffi.C.lexer_new
	local lexer_peek = ffi.C.lexer_peek
	local lexer_try_consume_string = ffi.C.lexer_try_consume_string
	local lexer_alphanumeric = ffi.C.lexer_alphanumeric
	local lexer_numeric = ffi.C.lexer_numeric
	local lexer_alpha = ffi.C.lexer_alpha
	local lexer_keyword = ffi.C.lexer_keyword
	local lexer_name = ffi.C.lexer_name
	local lexer_take = ffi.C.lexer_take
	local tokenbuf = ffi.new(qamar_token_t)
	local takebuf = ffi.new("size_t[1]")

	local function finalizer(x)
		local _ = lexer_destroy(x)
		_ = free(cast(void_tp, x))
	end

	function lexer.new(s)
		local len = slen(s)
		local size = len + typesize
		local l = cast(qamar_lexer_tp, malloc(size))
		if l ~= nil then
			local ret = lexer_new(l, s, len)
			if ret == 0 then
				copy(cast(void_tp, l.data), s, len)
				--io.stdout:write("OLE!!!\n")
				--io.stdout:flush()
				return gc(l, finalizer)
			end
			free(cast(void_tp, l))
		end
	end

	function lexer.peek(self, skip)
		local ret = lexer_peek(self, skip or 0)
		if ret ~= nil then
			return fstring(ret, 1)
		end
	end

	lexer.begin = ffi.C.lexer_begin
	lexer.commit = ffi.C.lexer_commit
	lexer.undo = ffi.C.lexer_undo
	lexer.skipws = ffi.C.lexer_skipws
	lexer.suspend_skip_ws = ffi.C.lexer_suspend_skip_ws
	lexer.resume_skip_ws = ffi.C.lexer_resume_skip_ws
	lexer.pos = ffi.C.lexer_pos

	function lexer.try_consume_string(self, s)
		local ret = lexer_try_consume_string(self, s, slen(s))
		if ret ~= nil then
			return s
		end
	end

	function lexer.alpha(self)
		local ret = lexer_alpha(self)
		if ret ~= nil then
			return ffi.string(ret, 1)
		end
	end

	function lexer.numeric(self)
		local ret = lexer_numeric(self)
		if ret ~= nil then
			return ffi.string(ret, 1)
		end
	end

	function lexer.alphanumeric(self)
		local ret = lexer_alphanumeric(self)
		if ret ~= nil then
			return ffi.string(ret, 1)
		end
	end

	local function create_token(t)
		return {
			pos = t.pos,
			type = t.type,
			value = fstring(t.value, t.len),
		}
	end

	function lexer.keyword(self)
		if lexer_keyword(self, tokenbuf) then
			return create_token(tokenbuf)
		end
	end

	function lexer.name(self)
		if lexer_name(self, tokenbuf) then
			return create_token(tokenbuf)
		end
	end

	function lexer.take(self, amt)
		takebuf[0] = amt or 1
		local ret = lexer_take(self, takebuf)
		if ret ~= nil then
			return fstring(ret, takebuf[0])
		end
	end
end

return lexer
