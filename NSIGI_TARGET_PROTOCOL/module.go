// Package nsigii provides Go bindings for NSIGII RIFT V1
// OBINexus Computing Framework
//
// This package implements zero-trust service architecture with color
// verification, phantom ID encoding, and RIFT tokenization stages.
package nsigii

import "C"
import (
	"errors"
	"fmt"
	"runtime"
	"unsafe"
)

// ============================================================================
// Enums
// ============================================================================

// ColorChannel represents color verification channels
type ColorChannel int

const (
	ColorRed      ColorChannel = 0 // Incoming data
	ColorGreen    ColorChannel = 1 // Verification
	ColorBlue     ColorChannel = 2 // Outgoing data
	ColorCyan     ColorChannel = 3 // RED + GREEN (1/2 shared)
	ColorYellow   ColorChannel = 4 // Warning
	ColorMagenta  ColorChannel = 5 // Critical
	ColorBlack    ColorChannel = 6 // Terminated
	ColorContrast ColorChannel = 7 // Inverse
)

// Polarity represents polarity states
type Polarity int

const (
	PolarityPositive Polarity = 1  // Positive
	PolarityNegative Polarity = -1 // Negative
	PolarityNeutral  Polarity = 0  // Neutral
)

// TokenType represents RIFT token types
type TokenType int

const (
	TokenEOF        TokenType = 0
	TokenIdentifier TokenType = 1
	TokenKeyword    TokenType = 2
	TokenNumber     TokenType = 3
	TokenOperator   TokenType = 4
	TokenDelimiter  TokenType = 5
	TokenString     TokenType = 6
	TokenComment    TokenType = 7
)

func (t TokenType) String() string {
	names := []string{
		"EOF", "IDENTIFIER", "KEYWORD", "NUMBER",
		"OPERATOR", "DELIMITER", "STRING", "COMMENT",
	}
	if int(t) < len(names) {
		return names[t]
	}
	return "UNKNOWN"
}

// ============================================================================
// Structures
// ============================================================================

// Token represents a RIFT token triplet
type Token struct {
	Type   TokenType // What it is (relation)
	Memory uint32    // Where it lives (memory pointer)
	Value  uint32    // What it contains (value/length)
	Text   string    // Extracted text from source
}

func (t Token) String() string {
	return fmt.Sprintf("Token(%s, mem=%d, val=%d, text='%s')",
		t.Type, t.Memory, t.Value, t.Text)
}

// Context represents an NSIGII service context
type Context struct {
	ctx       *C.NSigiiContext
	operation string
	service   string
}

// ============================================================================
// Context Management
// ============================================================================

// NewContext creates a new NSIGII context
//
// Schema: obinexus.[operation].[service]
//
// Example:
//   ctx, err := nsigii.NewContext("tokenize", "lexer")
//   if err != nil {
//       log.Fatal(err)
//   }
//   defer ctx.Close()
func NewContext(operation, service string) (*Context, error) {
	cOperation := C.CString(operation)
	cService := C.CString(service)
	defer C.free(unsafe.Pointer(cOperation))
	defer C.free(unsafe.Pointer(cService))

	ctx := C.nsigii_create_context(cOperation, cService)
	if ctx == nil {
		return nil, errors.New("failed to create NSIGII context")
	}

	nsigiiCtx := &Context{
		ctx:       ctx,
		operation: operation,
		service:   service,
	}

	// Set finalizer to ensure cleanup
	runtime.SetFinalizer(nsigiiCtx, (*Context).Close)

	return nsigiiCtx, nil
}

// Close releases the context resources
func (c *Context) Close() error {
	if c.ctx != nil {
		C.nsigii_destroy_context(c.ctx)
		c.ctx = nil
	}
	return nil
}

// Schema returns the service schema string
//
// Returns: obinexus.[operation].[service]
func (c *Context) Schema() (string, error) {
	if c.ctx == nil {
		return "", errors.New("context is closed")
	}

	schemaBuf := make([]byte, 256)
	cSchema := (*C.char)(unsafe.Pointer(&schemaBuf[0]))

	result := C.nsigii_generate_schema(c.ctx, cSchema, 256)
	if result != 0 {
		return "", fmt.Errorf("failed to generate schema: %d", result)
	}

	return C.GoString(cSchema), nil
}

// ============================================================================
// Tokenization (RIFT Stage 000-111)
// ============================================================================

// Tokenize tokenizes source code using RIFT Stage 000-111
//
// Example:
//   tokens, err := ctx.Tokenize("let x = 42;")
//   if err != nil {
//       log.Fatal(err)
//   }
//   for _, token := range tokens {
//       fmt.Println(token)
//   }
func (c *Context) Tokenize(source string) ([]Token, error) {
	if c.ctx == nil {
		return nil, errors.New("context is closed")
	}

	const maxTokens = 10000
	cSource := C.CString(source)
	defer C.free(unsafe.Pointer(cSource))

	// Allocate token buffer
	tokensBuf := make([]C.TokenTriplet, maxTokens)
	var count C.size_t

	// Perform tokenization
	result := C.nsigii_tokenize(
		c.ctx,
		cSource,
		(*C.TokenTriplet)(unsafe.Pointer(&tokensBuf[0])),
		C.size_t(maxTokens),
		&count,
	)

	if result != 0 {
		return nil, fmt.Errorf("tokenization failed: %d", result)
	}

	// Convert to Go tokens
	tokens := make([]Token, count)
	for i := 0; i < int(count); i++ {
		cToken := tokensBuf[i]

		// Extract text from source
		memPtr := int(cToken.memory)
		length := int(cToken.value)
		if length == 0 {
			length = 1
		}

		var text string
		if memPtr < len(source) {
			end := memPtr + length
			if end > len(source) {
				end = len(source)
			}
			text = source[memPtr:end]
		} else {
			text = "<EOF>"
		}

		tokens[i] = Token{
			Type:   TokenType(cToken._type),
			Memory: uint32(cToken.memory),
			Value:  uint32(cToken.value),
			Text:   text,
		}
	}

	return tokens, nil
}

// ============================================================================
// AUX Instructions
// ============================================================================

// AuxStart starts AUX instruction sequence
//
// noiseLevel: 0 for low entropy, 1 for high entropy
func (c *Context) AuxStart(noiseLevel int) error {
	if c.ctx == nil {
		return errors.New("context is closed")
	}

	result := C.nsigii_aux_start(c.ctx, C.int(noiseLevel))
	if result != 0 {
		return fmt.Errorf("AUX start failed: %d", result)
	}

	return nil
}

// AuxStop stops AUX instruction sequence
func (c *Context) AuxStop() error {
	if c.ctx == nil {
		return errors.New("context is closed")
	}

	result := C.nsigii_aux_stop(c.ctx)
	if result != 0 {
		return fmt.Errorf("AUX stop failed: %d", result)
	}

	return nil
}

// ============================================================================
// Color Verification
// ============================================================================

// VerifyRGBConsensus verifies RGB consensus (1/4 RED + 1/4 GREEN = 1/2 CYAN)
func (c *Context) VerifyRGBConsensus() (bool, error) {
	if c.ctx == nil {
		return false, errors.New("context is closed")
	}

	result := C.nsigii_verify_rgb_consensus(c.ctx)
	return bool(result), nil
}

// ============================================================================
// High-Level API
// ============================================================================

// Tokenize is a convenience function to tokenize source code
func Tokenize(source string) ([]Token, error) {
	ctx, err := NewContext("tokenize", "lexer")
	if err != nil {
		return nil, err
	}
	defer ctx.Close()

	return ctx.Tokenize(source)
}

// TokenStats represents token stream statistics
type TokenStats struct {
	TotalTokens      int
	TypeDistribution map[TokenType]int
	MemoryRange      [2]uint32
	AverageLength    float64
}

// AnalyzeTokens analyzes token stream for statistics
func AnalyzeTokens(tokens []Token) TokenStats {
	stats := TokenStats{
		TotalTokens:      len(tokens),
		TypeDistribution: make(map[TokenType]int),
	}

	if len(tokens) == 0 {
		return stats
	}

	var totalLength uint32
	minMem := tokens[0].Memory
	maxMem := tokens[0].Memory

	for _, token := range tokens {
		stats.TypeDistribution[token.Type]++
		totalLength += token.Value

		if token.Memory < minMem {
			minMem = token.Memory
		}
		if token.Memory > maxMem {
			maxMem = token.Memory
		}
	}

	stats.MemoryRange = [2]uint32{minMem, maxMem}
	stats.AverageLength = float64(totalLength) / float64(len(tokens))

	return stats
}

/*
*/
