default: generate

.PHONEY: generate
generate:
	go generate ./api/...
