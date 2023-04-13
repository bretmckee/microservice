package main

import (
	"context"
	"crypto/tls"
	"flag"
	"fmt"
	"log"

	backend "github.com/bretmckee/microservice/backend/backendapi"
	"google.golang.org/grpc"
	grpccred "google.golang.org/grpc/credentials"
)

func run(input, addr string, allowInsecure bool) (string, error) {
	cfg := &tls.Config{
		InsecureSkipVerify: allowInsecure,
	}
	opts := []grpc.DialOption{grpc.WithTransportCredentials(grpccred.NewTLS(cfg))}
	conn, err := grpc.Dial(addr, opts...)
	if err != nil {
		return "", fmt.Errorf("failed to connect to %s: %v", addr, err)
	}
	defer conn.Close()
	c := backend.NewBackendClient(conn)

	r, err := c.Process(context.Background(), &backend.ProcessRequest{Input: input})
	if err != nil {
		return "", fmt.Errorf("backend process failed: %v", err)
	}

	return r.GetOutput(), nil
}

func main() {
	var (
		input         = flag.String("input", "hello", "input to backend.Process")
		backend       = flag.String("backend", "localhost:8101", "port to listen on")
		allowInsecure = flag.Bool("insecure", false, "allow self signed certificates")
	)
	flag.Parse()

	r, err := run(*input, *backend, *allowInsecure)
	if err != nil {
		log.Fatalf("run returned an error: %v", err)
	}
	log.Printf("got: %s", r)
}
