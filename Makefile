PROTOC := /usr/local/protoc/bin/protoc
ANNOTATIONS_BASE_DIR := $(shell go list -m -f "{{.Dir}}" "github.com/grpc-ecosystem/grpc-gateway/v2")
ANNOTATIONS_DIR := $(ANNOTATIONS_BASE_DIR)/third_party/googleapis

CONTAINERS := backend frontend

.DEFAULT_GOAL := all

.PHONY: all
all: $(CONTAINERS)

.PHONY: grpc-tools
grpc-tools:
	go install \
    github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway \
    github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2 \
    google.golang.org/protobuf/cmd/protoc-gen-go \
    google.golang.org/grpc/cmd/protoc-gen-go-grpc

%.pb.go: proto/%.proto
	${PROTOC} -I "$(<D)" -I "${ANNOTATIONS_DIR}" --go_out="$(@D)" --go_opt=paths=source_relative $<

%_grpc.pb.go: proto/%.proto
	${PROTOC} -I "$(<D)" -I "${ANNOTATIONS_DIR}" --go-grpc_out="$(@D)" --go-grpc_opt=paths=source_relative $<

%.pb.gw.go: proto/%.proto
	${PROTOC} -I "$(<D)" -I "${ANNOTATIONS_DIR}" --grpc-gateway_out="$(@D)" --grpc-gateway_opt=logtostderr=true --grpc-gateway_opt=paths=source_relative $<

.PHONY: frontend-generated
frontend-generated: frontend/api/api.pb.go frontend/api/api_grpc.pb.go frontend/api/api.pb.gw.go

.PHONY: backend-generated
backend-generated: backend/api/api.pb.go backend/api/api_grpc.pb.go backend/api/api.pb.gw.go

.PHONY: generated
generated: frontend-generated backend-generated

.PHONY: clean
clean:
	rm frontend/api/*.go backend/api/*.go

.PHONY: $(CONTAINERS)
$(CONTAINERS): generated
	docker build -f Dockerfile  -t $@:dev --build-arg TARGET=$@ .
