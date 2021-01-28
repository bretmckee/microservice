# Download module dependencies
FROM golang:1.15.7-alpine3.13 AS download
ENV GO111MODULE on
WORKDIR /go/src
COPY go.mod go.sum ./
RUN go mod download -x

# Build the command
FROM golang:1.15.7-alpine3.13 AS build
RUN env
ARG TARGET
WORKDIR /go/src
COPY --from=download /go /go
COPY . .
RUN go build -o /tmp/cmd $TARGET/cmd/main.go

# Create the final container
FROM alpine:3.13
COPY --from=build /tmp/cmd /usr/local/bin/cmd
ENTRYPOINT ["/usr/local/bin/cmd"]
CMD ["-?"]
