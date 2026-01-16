//go:build gofuzz
package nplfuzz

import "github.com/obinexus/aegis/src/npl-protocols"

func FuzzNPL(data []byte) int {
    if len(data) == 0 { return -1 }
    _, err := nplprotocols.Parse(data) // return 0 = interesting, 1 = new coverage
    if err != nil { return 0 }
    return 1
}
