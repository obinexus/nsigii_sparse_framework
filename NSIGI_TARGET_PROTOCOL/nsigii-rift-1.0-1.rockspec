-- nsigii-rift-1.0-1.rockspec
-- NSIGII RIFT V1 Lua Binding
-- OBINexus Computing Framework

package = "nsigii-rift"
version = "1.0-1"

source = {
   url = "git://github.com/obinexus/nsigii-rift",
   tag = "v1.0-jan2026"
}

description = {
   summary = "NSIGII RIFT V1 - Zero Trust Service Architecture",
   detailed = [[
      NSIGII RIFT provides a comprehensive compiler toolchain with:
      - Color-based verification (RGB consensus)
      - Phantom ID zero-trust encoding
      - CISCO self-balancing tree structures
      - Multi-stage RIFT tokenization and parsing
      - Schema: obinexus.[operation].[service]
   ]],
   homepage = "https://github.com/obinexus/nsigii-rift",
   license = "OBINexus Proprietary"
}

dependencies = {
   "lua >= 5.1, < 5.5",
   "luaffi >= 1.3.0"  -- For FFI bindings
}

build = {
   type = "builtin",
   modules = {
      ["nsigii"] = "nsigii.lua",
      ["nsigii.rift"] = "nsigii/rift.lua",
      ["nsigii.phantom"] = "nsigii/phantom.lua",
      ["nsigii.cisco"] = "nsigii/cisco.lua"
   },
   copy_directories = {
      "doc",
      "riftfiles"
   }
}

-- ============================================================================
-- nsigii.lua - Main Module
-- ============================================================================

local ffi = require("ffi")

-- Load shared library
local lib = ffi.load("nsigii_rift")

-- ============================================================================
-- C Definitions
-- ============================================================================

ffi.cdef[[
    // Enums
    typedef enum {
        COLOR_RED = 0,
        COLOR_GREEN = 1,
        COLOR_BLUE = 2,
        COLOR_CYAN = 3,
        COLOR_YELLOW = 4,
        COLOR_MAGENTA = 5,
        COLOR_BLACK = 6,
        COLOR_CONTRAST = 7
    } ColorChannel;

    typedef enum {
        POLARITY_POS = 1,
        POLARITY_NEG = -1,
        POLARITY_NEUTRAL = 0
    } Polarity;

    typedef enum {
        TOKEN_EOF = 0,
        TOKEN_IDENTIFIER,
        TOKEN_KEYWORD,
        TOKEN_NUMBER,
        TOKEN_OPERATOR,
        TOKEN_DELIMITER,
        TOKEN_STRING,
        TOKEN_COMMENT
    } TokenType;

    // Structures
    typedef struct {
        TokenType type;
        uint32_t memory;
        uint32_t value;
    } TokenTriplet;

    typedef struct NSigiiContext NSigiiContext;

    // Functions
    NSigiiContext* nsigii_create_context(const char* operation, const char* service);
    void nsigii_destroy_context(NSigiiContext* ctx);
    
    int nsigii_tokenize(NSigiiContext* ctx, const char* input,
                       TokenTriplet* tokens, size_t max_tokens, size_t* count);
    
    int nsigii_generate_schema(NSigiiContext* ctx, char* schema_out, size_t len);
    
    int nsigii_aux_start(NSigiiContext* ctx, int noise);
    int nsigii_aux_stop(NSigiiContext* ctx);
    
    bool nsigii_verify_rgb_consensus(NSigiiContext* ctx);
]]

-- ============================================================================
-- Lua Module
-- ============================================================================

local M = {}
M._VERSION = "1.0-jan2026"
M._DESCRIPTION = "NSIGII RIFT V1 - Zero Trust Service Architecture"

-- ============================================================================
-- Enums
-- ============================================================================

M.ColorChannel = {
    RED = 0,
    GREEN = 1,
    BLUE = 2,
    CYAN = 3,
    YELLOW = 4,
    MAGENTA = 5,
    BLACK = 6,
    CONTRAST = 7
}

M.Polarity = {
    POSITIVE = 1,
    NEGATIVE = -1,
    NEUTRAL = 0
}

M.TokenType = {
    EOF = 0,
    IDENTIFIER = 1,
    KEYWORD = 2,
    NUMBER = 3,
    OPERATOR = 4,
    DELIMITER = 5,
    STRING = 6,
    COMMENT = 7
}

local token_type_names = {
    [0] = "EOF",
    [1] = "IDENTIFIER",
    [2] = "KEYWORD",
    [3] = "NUMBER",
    [4] = "OPERATOR",
    [5] = "DELIMITER",
    [6] = "STRING",
    [7] = "COMMENT"
}

-- ============================================================================
-- Context Class
-- ============================================================================

local Context = {}
Context.__index = Context

--- Create a new NSIGII context
-- @param operation Operation name (e.g., "tokenize", "parse", "analyze")
-- @param service Service name (e.g., "lexer", "syntax", "semantic")
-- @return Context object
function M.new_context(operation, service)
    local ctx = lib.nsigii_create_context(operation, service)
    if ctx == nil then
        error("Failed to create NSIGII context")
    end
    
    local self = {
        _ctx = ctx,
        operation = operation,
        service = service
    }
    
    return setmetatable(self, Context)
end

--- Close the context and release resources
function Context:close()
    if self._ctx ~= nil then
        lib.nsigii_destroy_context(self._ctx)
        self._ctx = nil
    end
end

--- Get the service schema string
-- @return Schema in format: obinexus.[operation].[service]
function Context:schema()
    if self._ctx == nil then
        error("Context is closed")
    end
    
    local schema_buf = ffi.new("char[256]")
    local result = lib.nsigii_generate_schema(self._ctx, schema_buf, 256)
    
    if result ~= 0 then
        error(string.format("Failed to generate schema: %d", result))
    end
    
    return ffi.string(schema_buf)
end

--- Tokenize source code using RIFT Stage 000-111
-- @param source Source code string to tokenize
-- @param max_tokens Maximum number of tokens (default: 10000)
-- @return Table of tokens
function Context:tokenize(source, max_tokens)
    if self._ctx == nil then
        error("Context is closed")
    end
    
    max_tokens = max_tokens or 10000
    
    -- Allocate token buffer
    local tokens_buf = ffi.new("TokenTriplet[?]", max_tokens)
    local count = ffi.new("size_t[1]")
    
    -- Perform tokenization
    local result = lib.nsigii_tokenize(
        self._ctx,
        source,
        tokens_buf,
        max_tokens,
        count
    )
    
    if result ~= 0 then
        error(string.format("Tokenization failed: %d", result))
    end
    
    -- Convert to Lua table
    local tokens = {}
    for i = 0, tonumber(count[0]) - 1 do
        local c_token = tokens_buf[i]
        
        -- Extract text from source
        local mem_ptr = tonumber(c_token.memory)
        local length = tonumber(c_token.value)
        if length == 0 then length = 1 end
        
        local text
        if mem_ptr < #source then
            text = source:sub(mem_ptr + 1, mem_ptr + length)
        else
            text = "<EOF>"
        end
        
        table.insert(tokens, {
            type = tonumber(c_token.type),
            type_name = token_type_names[tonumber(c_token.type)],
            memory = mem_ptr,
            value = length,
            text = text
        })
    end
    
    return tokens
end

--- Start AUX instruction sequence
-- @param noise_level 0 for low entropy, 1 for high entropy
function Context:aux_start(noise_level)
    if self._ctx == nil then
        error("Context is closed")
    end
    
    noise_level = noise_level or 0
    local result = lib.nsigii_aux_start(self._ctx, noise_level)
    
    if result ~= 0 then
        error(string.format("AUX start failed: %d", result))
    end
end

--- Stop AUX instruction sequence
function Context:aux_stop()
    if self._ctx == nil then
        error("Context is closed")
    end
    
    local result = lib.nsigii_aux_stop(self._ctx)
    
    if result ~= 0 then
        error(string.format("AUX stop failed: %d", result))
    end
end

--- Verify RGB consensus (1/4 RED + 1/4 GREEN = 1/2 CYAN)
-- @return true if consensus achieved, false otherwise
function Context:verify_rgb_consensus()
    if self._ctx == nil then
        error("Context is closed")
    end
    
    return lib.nsigii_verify_rgb_consensus(self._ctx)
end

-- ============================================================================
-- High-Level API
-- ============================================================================

--- Convenience function to tokenize source code
-- @param source Source code to tokenize
-- @param operation Operation name (default: "tokenize")
-- @param service Service name (default: "lexer")
-- @return Table of tokens
function M.tokenize(source, operation, service)
    operation = operation or "tokenize"
    service = service or "lexer"
    
    local ctx = M.new_context(operation, service)
    local tokens = ctx:tokenize(source)
    ctx:close()
    
    return tokens
end

--- Analyze token stream for statistics
-- @param tokens Table of tokens
-- @return Statistics table
function M.analyze_tokens(tokens)
    local stats = {
        total_tokens = #tokens,
        type_distribution = {},
        memory_range = {math.huge, -math.huge},
        average_length = 0
    }
    
    if #tokens == 0 then
        return stats
    end
    
    local total_length = 0
    
    for _, token in ipairs(tokens) do
        local type_name = token.type_name
        stats.type_distribution[type_name] = 
            (stats.type_distribution[type_name] or 0) + 1
        
        total_length = total_length + token.value
        
        if token.memory < stats.memory_range[1] then
            stats.memory_range[1] = token.memory
        end
        if token.memory > stats.memory_range[2] then
            stats.memory_range[2] = token.memory
        end
    end
    
    stats.average_length = total_length / #tokens
    
    return stats
end

-- ============================================================================
-- Example Usage
-- ============================================================================

function M.example()
    print("=== NSIGII RIFT V1 Lua Example ===\n")
    
    -- Example 1: Basic tokenization
    print("Example 1: Basic Tokenization")
    local source = "let x = 42;"
    local tokens = M.tokenize(source)
    
    print(string.format("Tokenized %d tokens:", #tokens))
    for i, token in ipairs(tokens) do
        print(string.format("  %d: %s (mem=%d, val=%d, text='%s')",
            i, token.type_name, token.memory, token.value, token.text))
    end
    
    -- Example 2: Context with schema
    print("\nExample 2: Schema Generation")
    local ctx = M.new_context("parse", "syntax")
    print("Schema: " .. ctx:schema())
    ctx:close()
    
    -- Example 3: Token analysis
    print("\nExample 3: Token Analysis")
    local stats = M.analyze_tokens(tokens)
    print(string.format("Total tokens: %d", stats.total_tokens))
    print(string.format("Average length: %.2f", stats.average_length))
    print("Type distribution:")
    for type_name, count in pairs(stats.type_distribution) do
        print(string.format("  %s: %d", type_name, count))
    end
end

return M
