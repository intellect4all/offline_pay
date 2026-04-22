// Package observability wires OpenTelemetry traces and Prometheus metrics
// into the offlinepay server. The OTel side is a no-op when
// OTEL_EXPORTER_OTLP_ENDPOINT is unset so dev workflows aren't forced to run
// a collector.
package observability

import (
	"context"
	"fmt"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// TracingConfig parameterizes Setup. An empty Endpoint disables tracing.
type TracingConfig struct {
	Endpoint    string
	ServiceName string
	Env         string
	SampleRatio float64
}

// Setup installs an OTel tracer provider and returns a shutdown closure.
// When cfg.Endpoint is empty, Setup wires a no-op provider and a no-op
// shutdown — calls to otel.Tracer still work but emit nothing.
func Setup(ctx context.Context, cfg TracingConfig) (func(context.Context) error, error) {
	if cfg.Endpoint == "" {
		// Install propagator anyway so incoming trace context is preserved.
		otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{}, propagation.Baggage{},
		))
		return func(context.Context) error { return nil }, nil
	}

	exp, err := otlptrace.New(ctx, otlptracegrpc.NewClient(
		otlptracegrpc.WithEndpoint(cfg.Endpoint),
		otlptracegrpc.WithInsecure(),
	))
	if err != nil {
		return nil, fmt.Errorf("otlp trace exporter: %w", err)
	}

	// NOTE: we intentionally do NOT merge with resource.Default(). The
	// default resource pins itself to a newer semconv schema URL than
	// our imports (1.26.0), which causes resource.Merge to fail with
	// "conflicting Schema URL". Building the resource directly from our
	// attributes avoids the collision while still giving spans the
	// service.name / deployment.environment attributes Tempo + Grafana
	// surface in trace search.
	res, err := resource.New(ctx,
		resource.WithSchemaURL(semconv.SchemaURL),
		resource.WithAttributes(
			semconv.ServiceName(cfg.ServiceName),
			semconv.DeploymentEnvironment(cfg.Env),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("otel resource: %w", err)
	}

	ratio := cfg.SampleRatio
	if ratio <= 0 {
		ratio = 1.0
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(ratio))),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{},
	))
	return tp.Shutdown, nil
}
