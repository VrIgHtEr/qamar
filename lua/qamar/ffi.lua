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
	local qamar_token_t = ffi.typeof("qamar_token_t")
	local qamar_lexer_t = ffi.typeof("qamar_lexer_t")
	local qamar_lexer_tp = ffi.typeof("qamar_lexer_t*")
	local void_tp = ffi.typeof("void*")

	local function finalizer(x)
		--io.stdout:write("DESTROY\n")
		--io.stdout:flush()
		ffi.C.lexer_destroy(x)
		ffi.C.free(ffi.cast(void_tp, x))
	end

	local slen = string.len
	function lexer.new(s)
		local len = slen(s)
		local typesize = ffi.sizeof(qamar_lexer_t)
		local size = len + typesize
		local l = ffi.cast(qamar_lexer_tp, ffi.C.malloc(size))
		if l == nil then
			return
		end
		local ret = ffi.C.lexer_new(l, s, len)
		if ret == 0 then
			ffi.copy(ffi.cast(void_tp, l.data), s, len)
			--io.stdout:write("OLE!!!\n")
			--io.stdout:flush()
			return ffi.gc(l, finalizer)
		end
		ffi.C.free(ffi.cast(void_tp, l))
	end

	function lexer.peek(self, skip)
		--io.stdout:write("PEEK\n")
		--io.stdout:flush()
		local ret = ffi.C.lexer_peek(self, skip or 0)
		if ret ~= nil then
			return ffi.string(ret, 1)
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
		--io.stdout:write("TRY_CONSUME_STRING\n")
		--io.stdout:flush()
		local len = slen(s)
		local ret = ffi.C.lexer_try_consume_string(self, s, len)
		if ret ~= nil then
			return s
		end
	end

	function lexer.alpha(self)
		--io.stdout:write("ALPHA\n")
		--io.stdout:flush()
		local ret = ffi.C.lexer_alpha(self)
		if ret ~= nil then
			return ffi.string(ret, 1)
		end
	end

	function lexer.numeric(self)
		--io.stdout:write("NUMERIC\n")
		--io.stdout:flush()
		local ret = ffi.C.lexer_numeric(self)
		if ret ~= nil then
			return ffi.string(ret, 1)
		end
	end

	function lexer.alphanumeric(self)
		--io.stdout:write("ALPHANUMERIC\n")
		--io.stdout:flush()
		local ret = ffi.C.lexer_alphanumeric(self)
		if ret ~= nil then
			return ffi.string(ret, 1)
		end
	end

	local function create_token(t)
		return {
			pos = t.pos,
			type = t.type,
			value = ffi.string(t.value, t.len),
		}
	end

	local tokenbuf = ffi.new(qamar_token_t)
	function lexer.keyword(self)
		--io.stdout:write("KEYWORD\n")
		--io.stdout:flush()
		if ffi.C.lexer_keyword(self, tokenbuf) then
			return create_token(tokenbuf)
		end
	end

	function lexer.name(self)
		--io.stdout:write("NAME\n")
		--io.stdout:flush()
		if ffi.C.lexer_name(self, tokenbuf) then
			return create_token(tokenbuf)
		end
	end

	local takebuf = ffi.new("size_t[1]")
	function lexer.take(self, amt)
		takebuf[0] = amt or 1
		--io.stdout:write("TAKE\n")
		--io.stdout:flush()
		local ret = ffi.C.lexer_take(self, takebuf)
		if ret ~= nil then
			return ffi.string(ret, takebuf[0])
		end
	end
end

return lexer
