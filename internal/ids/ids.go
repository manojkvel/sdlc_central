// Package ids makes the identifiers of the v2 track layout.
//
// Events and decisions use ULIDs: sortable by time, unique without coordination, so parallel
// branches never collide the way the v1 max+1 counters (HD-007, RISK-003, phase NN) did.
// Units are named by their tracker key (PAY-142, ADO-4567) when there is one.
package ids

import (
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"io"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/oklog/ulid/v2"
)

var (
	mu      sync.Mutex
	entropy = ulid.Monotonic(rand.Reader, 0)
)

// New returns a new ULID string. Within one process ULIDs are strictly increasing.
func New(t time.Time) string {
	mu.Lock()
	defer mu.Unlock()
	return ulid.MustNew(ulid.Timestamp(t), entropy).String()
}

// Deterministic returns the same ULID for the same time and seed. Migration uses it so that
// converting a v1 track twice gives identical event files (the migration is idempotent).
func Deterministic(t time.Time, seed string) string {
	h := sha256.Sum256([]byte(seed))
	var r io.Reader = &fixedReader{b: h[:]}
	return ulid.MustNew(ulid.Timestamp(t), r).String()
}

// DeterministicSeq is Deterministic with seq in the leading entropy bytes, so records that share a
// timestamp keep their original order (v1 timestamps have one-second resolution).
func DeterministicSeq(t time.Time, seq uint32, seed string) string {
	h := sha256.Sum256([]byte(seed))
	b := append([]byte{byte(seq >> 24), byte(seq >> 16), byte(seq >> 8), byte(seq)}, h[:6]...)
	return ulid.MustNew(ulid.Timestamp(t), &fixedReader{b: b}).String()
}

type fixedReader struct{ b []byte }

func (f *fixedReader) Read(p []byte) (int, error) { return copy(p, f.b), nil }

// Unit identifiers:
//
//	PAY-142            a Jira key
//	ADO-4567           an Azure Boards work item (AB#4567 and #4567 normalise to this)
//	u-01j9...          a unit with no tracker issue (lower-case ULID)
//	legacy-02-slug     a unit migrated from a v1 phase directory
var (
	trackerKey = regexp.MustCompile(`^[A-Z][A-Z0-9]{1,9}-[0-9]{1,9}$`)
	adoKey     = regexp.MustCompile(`^(?:AB)?#([0-9]{1,9})$`)
	localKey   = regexp.MustCompile(`^u-[0-9a-hjkmnp-tv-z]{26}$`)
	legacyKey  = regexp.MustCompile(`^legacy-[0-9]{2,}-[a-z0-9-]+$`)
)

// NormalizeUnit turns a user-supplied key into a unit id, or returns an error naming the accepted forms.
func NormalizeUnit(key string) (string, error) {
	k := strings.TrimSpace(key)
	if m := adoKey.FindStringSubmatch(strings.ToUpper(k)); m != nil {
		return "ADO-" + m[1], nil
	}
	up := strings.ToUpper(k)
	switch {
	case trackerKey.MatchString(up):
		return up, nil
	case localKey.MatchString(strings.ToLower(k)):
		return strings.ToLower(k), nil
	case legacyKey.MatchString(k):
		return k, nil
	}
	return "", fmt.Errorf("unit id %q: use a tracker key (PAY-142), an Azure Boards id (AB#4567), or omit it to generate u-<ULID>", key)
}

// NewLocalUnit returns a unit id for work with no tracker issue.
func NewLocalUnit(t time.Time) string { return "u-" + strings.ToLower(New(t)) }

// LegacyUnit names a unit migrated from a v1 phase directory such as 02-evidence-rail.
func LegacyUnit(phaseDir string) string { return "legacy-" + strings.ToLower(phaseDir) }

// ValidUnit reports whether id is already a normalised unit id.
func ValidUnit(id string) bool {
	return trackerKey.MatchString(id) || localKey.MatchString(id) || legacyKey.MatchString(id)
}
