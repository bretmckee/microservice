PATH := $(PATH):/usr/local/go/bin:$(HOME)/go/bin
SHELL := env PATH=$(PATH) /bin/sh
GO := /usr/local/go/bin/go
PROTOC := /usr/local/bin/protoc
ANNOTATIONS_BASE_DIR := $(shell $(GO) list -m -f "{{.Dir}}" "github.com/grpc-ecosystem/grpc-gateway/v2")
ANNOTATIONS_DIR := $(ANNOTATIONS_BASE_DIR)/third_party/googleapis
PROTO_INCLUDES := -I "${ANNOTATIONS_DIR}" -I /usr/include

BACKEND_SERVER := backend/cmd/server/server
BACKEND_CLIENT := backend/cmd/client/client
BACKEND_COMMANDS= $(BACKEND_SERVER) $(BACKEND_CLIENT)

FRONTEND_SERVER := frontend/cmd/server/server
FRONTEND_COMMANDS := $(FRONTEND_SERVER)

COMMANDS := $(BACKEND_COMMANDS) $(FRONTEND_COMMANDS)

CONTAINERS := backend frontend

.DEFAULT_GOAL := containers

.PHONY: commands
commands: $(COMMANDS)

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

$(BACKEND_SERVER): backend-api
$(FRONTEND_SERVER): frontend-api backend-api

# These targets are not really phony, but the dependencies are hard and the
# compiles are fast and if the yare declared PHONY they are always rebuilt.
.PHONY: $(COMMANDS)
$(COMMANDS):
	cd $(@D); CGO_ENABLED=0 $(GO) build ./...

.PHONY: frontend
frontend:
	docker build -f Dockerfile -t $(@) --build-arg TARGET=$(FRONTEND_SERVER) .

.PHONY: backend
backend:
	docker build -f Dockerfile -t $(@) --build-arg TARGET=$(BACKEND_SERVER) .

.PHONY: clean
clean:
	rm -f frontend/frontendapi/*.go backend/backendapi/*.go $(COMMANDS)

