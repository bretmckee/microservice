FROM golang:1.20.3-alpine3.17 AS base
RUN apk add --update --no-cache make protoc protobuf protobuf-dev docker openrc
RUN ln -s /usr/bin/protoc /usr/local/bin
WORKDIR /go/src
ENV HOME /tmp

FROM base AS download
ENV GO111MODULE on
WORKDIR /go/src
COPY go.mod go.sum ./
RUN go mod download -x
COPY tools.go Makefile ./
RUN make install-tools

# Build the command
FROM download AS build
RUN env
ARG TARGET
WORKDIR /go/src
COPY --from=download /go /go
COPY . .
RUN make apis
RUN make $TARGET

# Create the final container
FROM golang:1.20.3-alpine3.17 AS final
ARG TARGET
COPY --from=build /go/src/$TARGET /usr/local/bin/server
ENTRYPOINT ["/usr/local/bin/server"]
CMD ["-?"]
