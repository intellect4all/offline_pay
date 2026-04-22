//go:build e2e

// Session-management E2E walker. Hits the dockerised BFF on
// http://localhost:8082 and executes the 12-step walk from the
// session-management PRD. Run with:
//
//	go test -tags=e2e -run TestSessionsWalk -v ./cmd/e2e/...
package e2e

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

const sessionsBFF = "http://localhost:8082"

type sessTokens struct {
	UserID        string `json:"user_id"`
	AccountNumber string `json:"account_number"`
	AccessToken   string `json:"access_token"`
	RefreshToken  string `json:"refresh_token"`
}

func TestSessionsWalk(t *testing.T) {
	phone := "+2348100055005"
	code := "055005"

	// Wait for BFF
	var up bool
	for i := 0; i < 60; i++ {
		resp, err := http.Get(sessionsBFF + "/health")
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			up = true
			break
		}
		if resp != nil {
			resp.Body.Close()
		}
		time.Sleep(500 * time.Millisecond)
	}
	if !up {
		t.Fatalf("bff /health never became ready")
	}

	// 1. Fresh compose up (assumed by caller).
	// 2. Signup A.
	sessMustPostJSON(t, "/v1/auth/otp/request", "", map[string]any{
		"phone": phone, "purpose": "signup",
	}, nil)
	var t1 sessTokens
	sessMustPostJSON(t, "/v1/auth/otp/verify", "", map[string]any{
		"phone": phone, "code": code, "purpose": "signup",
	}, &t1)
	t.Logf("2  signup AT1 user=%s", t1.UserID)

	// 3. Second device: login.
	sessMustPostJSON(t, "/v1/auth/otp/request", "", map[string]any{
		"phone": phone, "purpose": "login",
	}, nil)
	var t2 sessTokens
	sessMustPostJSON(t, "/v1/auth/otp/verify", "", map[string]any{
		"phone": phone, "code": code, "purpose": "login",
	}, &t2)
	t.Logf("3  login AT2")

	sid1 := sessDecodeSid(t, t1.AccessToken)
	sid2 := sessDecodeSid(t, t2.AccessToken)
	if sid1 == "" || sid2 == "" || sid1 == sid2 {
		t.Fatalf("bad sids: sid1=%q sid2=%q", sid1, sid2)
	}

	// 4. GET /v1/auth/sessions with AT1.
	var list struct {
		Items []struct {
			ID        string `json:"id"`
			IsCurrent bool   `json:"is_current"`
		} `json:"items"`
	}
	sessMustGetJSON(t, "/v1/auth/sessions", t1.AccessToken, &list)
	if len(list.Items) != 2 {
		t.Fatalf("4  want 2 sessions, got %d: %+v", len(list.Items), list.Items)
	}
	var curFound bool
	for _, it := range list.Items {
		if it.ID == sid1 && it.IsCurrent {
			curFound = true
		}
		if it.ID == sid2 && it.IsCurrent {
			t.Fatalf("4  sid2 must not be is_current when viewed from AT1")
		}
	}
	if !curFound {
		t.Fatalf("4  no is_current=true row matching sid1")
	}
	t.Logf("4  GET /v1/auth/sessions -> 2 items, AT1 is_current=true")

	// 5. revoke-all-others (AT1).
	var rev struct {
		Revoked int32 `json:"revoked"`
	}
	sessMustPostJSON(t, "/v1/auth/sessions/revoke-all-others", t1.AccessToken, nil, &rev)
	if rev.Revoked != 1 {
		t.Fatalf("5  want revoked=1, got %d", rev.Revoked)
	}
	t.Logf("5  revoke-all-others -> revoked=1")

	// 6. refresh RT2 -> 401.
	_, st := sessDoBody(t, "POST", "/v1/auth/refresh", "", map[string]any{
		"refresh_token": t2.RefreshToken,
	})
	if st != 401 {
		t.Fatalf("6  want 401 on revoked RT2 refresh, got %d", st)
	}
	t.Logf("6  refresh RT2 -> 401 (session revoked)")

	// 7. AT1 still works.
	_, st = sessDoBody(t, "GET", "/v1/me", t1.AccessToken, nil)
	if st != 200 {
		t.Fatalf("7  want 200 on /v1/me with AT1, got %d", st)
	}
	t.Logf("7  /v1/me (AT1) -> 200")

	// 8. Set PIN via AT1 (1234), then fresh login AT3, set PIN 5678.
	_, st = sessDoBody(t, "POST", "/v1/auth/pin", t1.AccessToken, map[string]any{"pin": "1234"})
	if st != 204 {
		t.Fatalf("8a  want 204 on SetPIN(AT1), got %d", st)
	}

	sessMustPostJSON(t, "/v1/auth/otp/request", "", map[string]any{
		"phone": phone, "purpose": "login",
	}, nil)
	var t3 sessTokens
	sessMustPostJSON(t, "/v1/auth/otp/verify", "", map[string]any{
		"phone": phone, "code": code, "purpose": "login",
	}, &t3)
	sid3 := sessDecodeSid(t, t3.AccessToken)
	if sid3 == "" || sid3 == sid1 {
		t.Fatalf("8b  bad sid3=%q sid1=%q", sid3, sid1)
	}

	_, st = sessDoBody(t, "POST", "/v1/auth/pin", t3.AccessToken, map[string]any{"pin": "5678"})
	if st != 204 {
		t.Fatalf("8c  want 204 on SetPIN(AT3), got %d", st)
	}
	t.Logf("8  SetPIN via AT3 rotated the PIN")

	// 9. refresh RT1 -> 401 (revoked by PIN change on AT3).
	_, st = sessDoBody(t, "POST", "/v1/auth/refresh", "", map[string]any{
		"refresh_token": t1.RefreshToken,
	})
	if st != 401 {
		t.Fatalf("9  want 401 refresh RT1 after AT3's SetPIN, got %d", st)
	}
	t.Logf("9  refresh RT1 -> 401 (PIN change forced eviction)")

	// 10. revoke current session -> 400 cannot_revoke_current.
	body, st := sessDoBody(t, "POST", "/v1/auth/sessions/"+sid3+"/revoke", t3.AccessToken, nil)
	if st != 400 {
		t.Fatalf("10  want 400, got %d body=%s", st, body)
	}
	if !strings.Contains(body, "cannot_revoke_current") {
		t.Fatalf("10  want code=cannot_revoke_current, got body=%s", body)
	}
	t.Logf("10  revoke current -> 400 cannot_revoke_current")

	// 11. logout AT3 -> 204.
	_, st = sessDoBody(t, "POST", "/v1/auth/logout", "", map[string]any{
		"refresh_token": t3.RefreshToken,
	})
	if st != 204 {
		t.Fatalf("11  want 204 on logout AT3, got %d", st)
	}
	t.Logf("11  logout AT3 -> 204")
}

func sessMustPostJSON(t *testing.T, path, at string, body, out any) {
	t.Helper()
	data, st := sessDoBody(t, "POST", path, at, body)
	if st < 200 || st >= 300 {
		t.Fatalf("POST %s: status=%d body=%s", path, st, data)
	}
	if out != nil && data != "" {
		if err := json.Unmarshal([]byte(data), out); err != nil {
			t.Fatalf("POST %s unmarshal: %v body=%s", path, err, data)
		}
	}
}

func sessMustGetJSON(t *testing.T, path, at string, out any) {
	t.Helper()
	data, st := sessDoBody(t, "GET", path, at, nil)
	if st != 200 {
		t.Fatalf("GET %s: status=%d body=%s", path, st, data)
	}
	if err := json.Unmarshal([]byte(data), out); err != nil {
		t.Fatalf("GET %s unmarshal: %v body=%s", path, err, data)
	}
}

func sessDoBody(t *testing.T, method, path, at string, body any) (string, int) {
	t.Helper()
	var reqBody io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		reqBody = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, sessionsBFF+path, reqBody)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if at != "" {
		req.Header.Set("Authorization", "Bearer "+at)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("%s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	return string(data), resp.StatusCode
}

func sessDecodeSid(t *testing.T, tok string) string {
	t.Helper()
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		return ""
	}
	b, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return ""
	}
	var c struct {
		Sid string `json:"sid"`
	}
	_ = json.Unmarshal(b, &c)
	_ = fmt.Sprintf // keep fmt usage stable
	return c.Sid
}
