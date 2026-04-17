package domain

import "testing"

func validGossipBlob() GossipBlob {
	blob := []byte{0xaa, 0xbb, 0xcc, 0xdd}
	return GossipBlob{
		TransactionHash:  []byte{0x01, 0x02},
		EncryptedBlob:    blob,
		BankSignature:    []byte{0x09, 0x08},
		CeilingTokenHash: []byte{0x03, 0x04},
		HopCount:         1,
		BlobSize:         len(blob),
	}
}

func TestGossipBlob_Validate_Happy(t *testing.T) {
	if err := validGossipBlob().Validate(); err != nil {
		t.Fatalf("expected valid, got %v", err)
	}
}

func TestGossipBlob_Validate_HopBoundaries(t *testing.T) {
	b := validGossipBlob()
	b.HopCount = 0
	if err := b.Validate(); err != nil {
		t.Errorf("hop=0 should be valid, got %v", err)
	}
	b.HopCount = MaxGossipHops
	if err := b.Validate(); err != nil {
		t.Errorf("hop=%d should be valid, got %v", MaxGossipHops, err)
	}
	b.HopCount = MaxGossipHops + 1
	if err := b.Validate(); err == nil {
		t.Errorf("hop=%d should be invalid", b.HopCount)
	}
	b.HopCount = -1
	if err := b.Validate(); err == nil {
		t.Errorf("negative hop should be invalid")
	}
}

func TestGossipBlob_Validate_Errors(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*GossipBlob)
	}{
		{"zero blob size", func(b *GossipBlob) { b.BlobSize = 0; b.EncryptedBlob = nil }},
		{"blob size mismatch", func(b *GossipBlob) { b.BlobSize = 999 }},
		{"missing txn hash", func(b *GossipBlob) { b.TransactionHash = nil }},
		{"missing ceiling hash", func(b *GossipBlob) { b.CeilingTokenHash = nil }},
		{"missing bank signature", func(b *GossipBlob) { b.BankSignature = nil }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			b := validGossipBlob()
			c.mutate(&b)
			if err := b.Validate(); err == nil {
				t.Fatalf("expected error for %s", c.name)
			}
		})
	}
}
