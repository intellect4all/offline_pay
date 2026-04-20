// rotate_sealedbox_key mints a fresh X25519 keypair for the gossip
// sealed-box recipient and emits the new keyfile plus the env-var
// updates needed to promote it.
//
// Forward-secrecy rationale: SealAnonymous (NaCl crypto_box_seal) uses a
// fresh ephemeral sender key per blob, which gives forward secrecy
// against sender-side compromise. The remaining attack surface is the
// server's long-term recipient key — every gossip blob ever uploaded can
// be decrypted by whoever holds it. Forward secrecy against server-key
// compromise requires:
//
//  1. Generate a new recipient keypair and promote it to SERVER_SEALED_BOX_PRIVKEY.
//  2. Demote the outgoing keyfile into SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS
//     so in-flight blobs sealed to it still decrypt during the overlap
//     window.
//  3. *After the overlap window expires*, securely delete the retired
//     keyfile (shred on disk, wipe key-management store). At that point
//     any blob still sealed to the retired key becomes permanently
//     undecryptable — that is the forward-secrecy property.
//
// This command handles steps 1 and prints the commands for step 2.
// Step 3 is intentionally manual — destruction of keying material should
// require explicit operator intent.
//
// Usage:
//
//	go run ./cmd/rotate_sealedbox_key --out=/etc/offlinepay/sealedbox.key
package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/intellect/offlinepay/internal/crypto"
)

func main() {
	var out string
	flag.StringVar(&out, "out", "", "path to write the new 32-byte X25519 private key (hex). Required.")
	flag.Parse()

	if out == "" {
		log.Fatal("--out required")
	}

	pub, priv, err := crypto.GenerateSealedBoxKeyPair()
	if err != nil {
		log.Fatalf("generate: %v", err)
	}

	privHex := hex.EncodeToString(priv[:])
	if err := os.WriteFile(out, []byte(privHex+"\n"), 0o600); err != nil {
		log.Fatalf("write keyfile: %v", err)
	}

	fmt.Printf("wrote new sealed-box private key to %s (mode 0600)\n", out)
	fmt.Printf("public  = %s\n", hex.EncodeToString(pub[:]))
	fmt.Println()
	fmt.Println("promote the new key (next server restart):")
	fmt.Printf("  export SERVER_SEALED_BOX_PRIVKEY=$(cat %s)\n", out)
	fmt.Println()
	fmt.Println("keep the old key reachable during the overlap window:")
	fmt.Println("  export SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS=\"<old_hex>[,<older_hex>...]\"")
	fmt.Println()
	fmt.Println("after the overlap window elapses, securely delete the retired keyfile")
	fmt.Println("to achieve forward secrecy against server-key compromise.")
}
