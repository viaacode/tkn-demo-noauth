# Multi-stage build for minimal image size
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy source code
COPY main.go .

# Build the application
RUN go build -o hello-world main.go

# Runtime stage
FROM alpine:3.18

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/hello-world .

# Add non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ "/app/hello-world", "-health" ] || exit 1

EXPOSE 8080

ENTRYPOINT ["/app/hello-world"]
