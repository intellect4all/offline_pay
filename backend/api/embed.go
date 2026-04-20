// Package api embeds the OpenAPI specification so the BFF can serve it
// directly from its binary (no filesystem dependency at runtime).
package api

import _ "embed"

//go:embed openapi.yaml
var OpenAPISpec []byte
