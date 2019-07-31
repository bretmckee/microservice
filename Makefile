default: containers

.PHONEY: generate
generate:
	go generate ./api/...


.PHONEY: containers
containers:
	docker build -f Dockerfile.frontend -t bretmckee/microservice-frontend .
	docker build -f Dockerfile.backend -t bretmckee/microservice-backend .
