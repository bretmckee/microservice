default: containers

.PHONEY: generate
generate:
	go generate ./api/...


.PHONEY: containers
containers:
	docker build -f Dockerfile.frontend -t frontend .
	docker build -f Dockerfile.backend -t backend .
