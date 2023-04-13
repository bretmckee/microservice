PATH := $(PATH):/usr/local/go/bin:$(HOME)/go/bin
SHELL := env PATH=$(PATH) /bin/sh
GO := /usr/local/go/bin/go
PROTOC := /usr/local/bin/protoc
ANNOTATIONS_BASE_DIR := $(shell $(GO) list -m -f "{{.Dir}}" "github.com/grpc-ecosystem/grpc-gateway/v2")
ANNOTATIONS_DIR := $(ANNOTATIONS_BASE_DIR)/third_party/googleapis
PROTO_INCLUDES := -I "${ANNOTATIONS_DIR}" -I /usr/include

# The container/ prefix is just to avoid name collisions with the binaries. It
# is stripped off by the rules that use the targets.
CONTAINERS := container/backend container/frontend

.DEFAULT_GOAL := containers

.PHONY: containers
containers: $(CONTAINERS)

.PHONY: download
download:
	@echo Download go.mod dependencies
	@$(GO) mod download -x

.PHONY: install-tools
install-tools: download
	@echo Installing tools from tools.go
	@cat tools.go | grep _ | awk -F'"' '{print $$2}' | xargs -tI % $(GO) install %


%.pb.go: proto/%.proto
	${PROTOC} -I "$(<D)" $(PROTO_INCLUDES) --go_out="$(@D)" --go_opt=paths=source_relative $<

%_grpc.pb.go: proto/%.proto
	${PROTOC} -I "$(<D)" $(PROTO_INCLUDES) --go-grpc_out="$(@D)" --go-grpc_opt=paths=source_relative $<

%.pb.gw.go: proto/%.proto
	${PROTOC} -I "$(<D)" $(PROTO_INCLUDES) --grpc-gateway_out="$(@D)" --grpc-gateway_opt=logtostderr=true --grpc-gateway_opt=paths=source_relative $<

.PHONY: frontend-api
frontend-api: frontend/frontendapi/frontend_api.pb.go frontend/frontendapi/frontend_api_grpc.pb.go frontend/frontendapi/frontend_api.pb.gw.go

.PHONY: backend-api
backend-api: backend/backendapi/backend_api.pb.go backend/backendapi/backend_api_grpc.pb.go backend/backendapi/backend_api.pb.gw.go

.PHONY: apis
api: frontend-api backend-api

backend: backend-api
frontend: frontend-api backend-api

.PHONY: backend frontend
backend frontend:
	CGO_ENABLED=0 $(GO) build -o $(@)/cmd/$(@) $(@)/cmd/main.go

.PHONY: clean
clean:
	rm -f frontend/frontendapi/*.go backend/backendapi/*.go

.PHONY:
container/frontend container/backend:
	docker build -f Dockerfile -t $(@F) --build-arg TARGET=$(@F) .
