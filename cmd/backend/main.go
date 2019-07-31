package main

import (
	"context"
	"crypto/tls"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"

	pb "github.com/bretmckee/microservice/api/backend"
	"github.com/golang/protobuf/proto"
	"github.com/grpc-ecosystem/grpc-gateway/runtime"
	"google.golang.org/grpc"
	grpccred "google.golang.org/grpc/credentials"
)

type server struct{}

func (s *server) process(ctx context.Context, req *pb.ProcessRequest) (*pb.ProcessReply, error) {
	reply := &pb.ProcessReply{
		Output: fmt.Sprintf("backend input was: %q", req.GetInput()),
	}

	return reply, nil
}

func (s *server) Process(ctx context.Context, req *pb.ProcessRequest) (*pb.ProcessReply, error) {
	log.Printf("Backend begins processing request:{%s}", strings.TrimSpace(proto.MarshalTextString(req)))
	reply, err := s.process(ctx, req)
	if err != nil {
		log.Printf("Error processing request: %v", err)
		return reply, err
	}
	log.Printf("Done processing request, reply:{%s}", strings.TrimSpace(proto.MarshalTextString(reply)))
	return reply, err
}

func readTLSFiles(certFile, keyFile string) (tls.Certificate, error) {
	if certFile == "" {
		return tls.Certificate{}, fmt.Errorf("certfile must be specified")
	}
	if _, err := os.Stat(certFile); os.IsNotExist(err) {
		return tls.Certificate{}, fmt.Errorf("cannot open the cert file %s", certFile)
	}
	if keyFile == "" {
		return tls.Certificate{}, fmt.Errorf("keyfile must must be specified")
	}
	if _, err := os.Stat(keyFile); os.IsNotExist(err) {
		return tls.Certificate{}, fmt.Errorf("cannot open the key file %s", keyFile)
	}

	return tls.LoadX509KeyPair(certFile, keyFile)
}

// grpcHandlerFunc returns an http.Handler that delegates to grpcServer on incoming gRPC
// connections or otherHandler otherwise. Copied from cockroachdb.
func grpcHandlerFunc(grpcServer *grpc.Server, otherHandler http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor == 2 && strings.Contains(r.Header.Get("Content-Type"), "application/grpc") {
			grpcServer.ServeHTTP(w, r)
		} else {
			otherHandler.ServeHTTP(w, r)
		}
	})
}

func run(certFile, keyFile, addr string, allowInsecure bool) error {
	cert, err := readTLSFiles(certFile, keyFile)
	if err != nil {
		return fmt.Errorf("unable to load certificates: %v", err)
	}

	tlsConfig := tls.Config{
		InsecureSkipVerify: allowInsecure,
		Certificates:       []tls.Certificate{cert},
	}

	opts := []grpc.ServerOption{grpc.Creds(grpccred.NewTLS(&tlsConfig))}

	grpcServer := grpc.NewServer(opts...)
	pb.RegisterBackendServer(grpcServer, &server{})

	ctx := context.Background()
	gwmux := runtime.NewServeMux()
	dopts := []grpc.DialOption{grpc.WithTransportCredentials(grpccred.NewTLS(&tlsConfig))}
	if err := pb.RegisterBackendHandlerFromEndpoint(ctx, gwmux, addr, dopts); err != nil {
		return fmt.Errorf("failed to register handler from endpoint: %v", err)
	}

	mux := http.NewServeMux()
	mux.Handle("/", gwmux)

	lis, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("failed to listen on addr %s: %v", addr, err)
	}

	srv := &http.Server{
		Addr:    addr,
		Handler: grpcHandlerFunc(grpcServer, mux),
		TLSConfig: &tls.Config{
			Certificates: []tls.Certificate{cert},
			NextProtos:   []string{"h2"},
		},
	}
	if err := srv.Serve(tls.NewListener(lis, srv.TLSConfig)); err != nil {
		return fmt.Errorf("failed to serve: %v", err)
	}

	return nil
}

func getIpAddresses() ([]string, error) {
	interfaces, err := net.InterfaceAddrs()
	if err != nil {
		return nil, fmt.Errorf("faild ot list interfaces: %v", err)
	}
	var addrs []string
	for _, a := range interfaces {
		if ipnet, ok := a.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				addrs = append(addrs, ipnet.IP.String())
			}
		}
	}
	return addrs, nil
}

func main() {
	var (
		certFile      = flag.String("certfile", "", "certificate file")
		allowInsecure = flag.Bool("insecure", false, "allow self signed certificates")
		keyFile       = flag.String("keyfile", "", "private key file")
		addr          = flag.String("addr", ":443", "[address]:port to listen on")
	)
	flag.Parse()

	ips, err := getIpAddresses()
	if err != nil {
		log.Fatalf("Unable to get ip addresses: %v", err)
	}
	log.Printf("backend begins: available interfaces: %s; addr= %q", strings.Join(ips, ", "), *addr)

	if err := run(*certFile, *keyFile, *addr, *allowInsecure); err != nil {
		log.Fatalf("run returned an error: %v", err)
	}

}
