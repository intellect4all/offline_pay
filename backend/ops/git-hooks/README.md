# Git hooks

Local pre-commit hook for this PoC. No remote CI is configured.

Install once per clone from the `backend/` directory:

```
make install-hooks
```

The hook runs `go vet`, `go test ./...`, and (if `dart` is on PATH) the Dart
core-package test suite. Slow suites (integration, e2e, scale, fuzz) are
opt-in via `make check-all`.
