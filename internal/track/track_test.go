package track

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFindAndLayout(t *testing.T) {
	p := t.TempDir()
	tr, err := Find(p)
	if err != nil || tr.Layout != 0 || tr.Require() == nil {
		t.Fatalf("empty project: %+v %v", tr, err)
	}
	os.MkdirAll(filepath.Join(p, ".track"), 0o755)
	os.WriteFile(filepath.Join(p, ".track", "state.md"), []byte("## AIDLC_RESUME\n"), 0o644)
	if tr, _ = Find(p); tr.Layout != 1 {
		t.Fatalf("want layout 1, got %d", tr.Layout)
	}
	os.WriteFile(filepath.Join(p, ".track", "layout-version"), []byte("2\n"), 0o644)
	if tr, _ = Find(p); tr.Layout != 2 {
		t.Fatalf("want layout 2, got %d", tr.Layout)
	}
	// track_root from sdlc-central.json
	os.MkdirAll(filepath.Join(p, ".sdlc"), 0o755)
	os.WriteFile(filepath.Join(p, ".sdlc", "sdlc-central.json"), []byte(`{"track_root":"gov/track"}`), 0o644)
	if tr, _ = Find(p); tr.Root != filepath.Join(p, "gov", "track") || tr.Rel(tr.EventsDir()) != "gov/track/events" {
		t.Fatalf("track_root not honoured: %s", tr.Root)
	}
	t.Setenv("AIDLC_TRACK_ROOT", filepath.Join(p, "elsewhere"))
	if tr, _ = Find(p); tr.Root != filepath.Join(p, "elsewhere") {
		t.Fatalf("AIDLC_TRACK_ROOT not honoured: %s", tr.Root)
	}
}
