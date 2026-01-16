
#cgo LDFLAGS: -lnsigii_rift
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

typedef enum {
    COLOR_RED = 0,
    COLOR_GREEN = 1,
    COLOR_BLUE = 2,
    COLOR_CYAN = 3
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

typedef struct {
    TokenType type;
    uint32_t memory;
    uint32_t value;
} TokenTriplet;

typedef struct NSigiiContext NSigiiContext;

NSigiiContext* nsigii_create_context(const char* operation, const char* service);
void nsigii_destroy_context(NSigiiContext* ctx);
int nsigii_tokenize(NSigiiContext* ctx, const char* input,
                   TokenTriplet* tokens, size_t max_tokens, size_t* count);
int nsigii_generate_schema(NSigiiContext* ctx, char* schema_out, size_t len);
int nsigii_aux_start(NSigiiContext* ctx, int noise);
int nsigii_aux_stop(NSigiiContext* ctx);
bool nsigii_verify_rgb_consensus(NSigiiContext* ctx);