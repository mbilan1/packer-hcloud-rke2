# Golden Image Controller — multi-stage build
#
# Stage 1: Build the Go binary
# Stage 2: Minimal runtime image (distroless)

FROM golang:1.23-alpine AS builder

WORKDIR /build

COPY go.mod go.sum* ./
COPY main.go .
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /golden-image-controller .

# ── Runtime ──────────────────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /golden-image-controller /golden-image-controller

USER nonroot:nonroot

ENTRYPOINT ["/golden-image-controller"]
