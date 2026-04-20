package config

import (
	"testing"
	"time"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("OFFLINEPAY_ENV", "")
	t.Setenv("CEILING_TTL_HOURS", "")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Env != "local" {
		t.Errorf("Env default = %q, want local", c.Env)
	}
	if c.CeilingTTL != 24*time.Hour {
		t.Errorf("CeilingTTL default = %v, want 24h", c.CeilingTTL)
	}
	if c.AutoSettleTimeout != 72*time.Hour {
		t.Errorf("AutoSettleTimeout default = %v, want 72h", c.AutoSettleTimeout)
	}
	if c.ClockGrace != 30*time.Minute {
		t.Errorf("ClockGrace default = %v, want 30m", c.ClockGrace)
	}
}

func TestLoadInvalidInt(t *testing.T) {
	t.Setenv("CEILING_TTL_HOURS", "notanumber")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for non-integer CEILING_TTL_HOURS")
	}
}
