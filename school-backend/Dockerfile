FROM golang:1.25.0-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/main . \
  && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/seed ./cmd/seed

FROM alpine:3.21
WORKDIR /app
RUN apk add --no-cache ca-certificates curl tzdata
RUN addgroup -S app && adduser -S app -G app
RUN mkdir -p /app/uploads/avatars /app/uploads/schools /app/uploads/exports && chown -R app:app /app/uploads
COPY --from=builder --chown=app:app /out/main /app/main
COPY --from=builder --chown=app:app /out/seed /app/seed
USER app

EXPOSE 8080
CMD ["./main"]
