package ids

import (
	"testing"
	"time"
)

func TestNewIsMonotonic(t *testing.T) {
	now := time.Now()
	prev := ""
	for i := 0; i < 1000; i++ {
		id := New(now)
		if id <= prev {
			t.Fatalf("not increasing: %s after %s", id, prev)
		}
		prev = id
	}
}

func TestDeterministic(t *testing.T) {
	at := time.Date(2026, 9, 1, 10, 0, 0, 0, time.UTC)
	a, b := Deterministic(at, "line one"), Deterministic(at, "line one")
	if a != b {
		t.Fatalf("same input gave %s and %s", a, b)
	}
	if Deterministic(at, "line two") == a {
		t.Fatal("different seeds gave the same id")
	}
	if Deterministic(at.Add(time.Second), "line one") <= a {
		t.Fatal("later time should sort later")
	}
}

func TestNormalizeUnit(t *testing.T) {
	cases := map[string]string{
		"PAY-142": "PAY-142", "pay-142": "PAY-142", " PAY-142 ": "PAY-142",
		"AB#4567": "ADO-4567", "#4567": "ADO-4567", "ADO-4567": "ADO-4567",
		"legacy-02-evidence-rail": "legacy-02-evidence-rail",
	}
	for in, want := range cases {
		got, err := NormalizeUnit(in)
		if err != nil || got != want {
			t.Errorf("NormalizeUnit(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"", "password reset", "PAY", "142", "../etc"} {
		if _, err := NormalizeUnit(bad); err == nil {
			t.Errorf("NormalizeUnit(%q) should fail", bad)
		}
	}
	u := NewLocalUnit(time.Now())
	if got, err := NormalizeUnit(u); err != nil || got != u || !ValidUnit(u) {
		t.Errorf("local unit %s did not round-trip: %q %v", u, got, err)
	}
}
