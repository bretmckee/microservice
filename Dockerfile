FROM golang:1.20.3-alpine3.17 AS base
ENV GO111MODULE on
RUN apk add --no-cache make protoc protobuf protobuf-dev
RUN ln -s /usr/bin/protoc /usr/local/bin

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
RUN make api
RUN make $TARGET

# Create the final container
FROM golang:1.20.3-alpine3.17 AS final
ARG TARGET
COPY --from=build /go/src/$TARGET/cmd/$TARGET /usr/local/bin/cmd
ENTRYPOINT ["/usr/local/bin/cmd"]
CMD ["-?"]
