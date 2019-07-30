package main

//go:generate protoc -I ../../api/frontend --go_out=plugins=grpc:../../api/frontend ../../api/frontend/frontend.proto

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"

	pb "github.com/bretmckee/microservice/api/frontend"
	"google.golang.org/grpc"
)

type server struct{}

func (s *server) Process(ctx context.Context, req *pb.ProcessRequest) (*pb.ProcessReply, error) {
	return nil, fmt.Errorf("Not implemented")
}

func main() {
	portPtr := flag.String("port", ":8100", "port to listen on")
	flag.Parse()

	fmt.Println("server started")

	lis, err := net.Listen("tcp", *portPtr)
	if err != nil {
		log.Fatalf("failed to listen on port %s: %v", *portPtr, err)
	}
	s := grpc.NewServer()
	pb.RegisterFrontendServer(s, &server{})
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
