package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	backend "github.com/bretmckee/microservice/api/backend"
	pb "github.com/bretmckee/microservice/api/frontend"
	"github.com/golang/protobuf/proto"
	"github.com/grpc-ecosystem/grpc-gateway/runtime"
	"google.golang.org/grpc"
	grpccred "google.golang.org/grpc/credentials"
)

type server struct {
	config  *tls.Config
	backend string
}

func newServer(certFile, backend string, allowInsecure bool) (*server, error) {
	config, err := readCert(certFile)
	if err != nil {
		return nil, fmt.Errorf("NewServer failed to read certfile %q: %v", certFile, err)
	}

	if backend == "" {
		return nil, fmt.Errorf("NewServer: backend must be specified")
	}
	config.InsecureSkipVerify = allowInsecure

	return &server{
		config:  config,
		backend: backend,
	}, nil
}

func (s *server) process(ctx context.Context, req *pb.ProcessRequest) (*pb.ProcessReply, error) {
	opts := []grpc.DialOption{grpc.WithTransportCredentials(grpccred.NewTLS(s.config))}
	// Set up a connection to the server.
	conn, err := grpc.Dial(s.backend, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to %s: %v", s.backend, err)
	}
	defer conn.Close()
	c := backend.NewBackendClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	r, err := c.Process(ctx, &backend.ProcessRequest{Input: req.GetInput()})
	if err != nil {
		return nil, fmt.Errorf("backend process failed: %v", err)
	}

	reply := &pb.ProcessReply{
		Output: r.GetOutput(),
	}

	return reply, nil
}

func (s *server) Process(ctx context.Context, req *pb.ProcessRequest) (*pb.ProcessReply, error) {
	log.Printf("Frontend begins processing request:{%s}", strings.TrimSpace(proto.MarshalTextString(req)))
	reply, err := s.process(ctx, req)
	if err != nil {
		log.Printf("Error processing request: %v", err)
		return reply, err
	}
	log.Printf("Done processing request, reply:{%s}", strings.TrimSpace(proto.MarshalTextString(reply)))
	return reply, err
}

func readCert(certFile string) (*tls.Config, error) {
	if certFile == "" {
		return nil, fmt.Errorf("certfile must be specified")
	}
	caCert, err := ioutil.ReadFile(certFile)
	if err != nil {
		return nil, fmt.Errorf("readCert failed to read %s: %v", certFile, err)
	}
	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)
	return &tls.Config{RootCAs: caCertPool}, nil
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

func run(certFile, keyFile, port, backend string, allowInsecure bool) error {
	cert, err := readTLSFiles(certFile, keyFile)
	if err != nil {
		return fmt.Errorf("unable to load certificates: %v", err)
	}

	tlsConfig := tls.Config{
		InsecureSkipVerify: allowInsecure,
		Certificates:       []tls.Certificate{cert},
	}

	opts := []grpc.ServerOption{grpc.Creds(grpccred.NewTLS(&tlsConfig))}

	s, err := newServer(certFile, backend, allowInsecure)
	if err != nil {
		return fmt.Errorf("unable to create server: %v", err)
	}

	grpcServer := grpc.NewServer(opts...)
	pb.RegisterFrontendServer(grpcServer, s)

	ctx := context.Background()
	gwmux := runtime.NewServeMux()
	dopts := []grpc.DialOption{grpc.WithTransportCredentials(grpccred.NewTLS(&tlsConfig))}
	if err := pb.RegisterFrontendHandlerFromEndpoint(ctx, gwmux, port, dopts); err != nil {
		return fmt.Errorf("failed to regsiter handler from endpoint: %v", err)
	}

	mux := http.NewServeMux()
	mux.Handle("/", gwmux)

	lis, err := net.Listen("tcp", port)
	if err != nil {
		return fmt.Errorf("failed to listen on port %s: %v", port, err)
	}

	srv := &http.Server{
		Addr:    port,
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
		backend       = flag.String("backend", "localhost:8101", "port to listen on")
		certFile      = flag.String("certfile", "", "certificate file")
		allowInsecure = flag.Bool("insecure", false, "allow self signed certificates")
		keyFile       = flag.String("keyfile", "", "private key file")
		addr          = flag.String("addr", ":443", "port to listen on")
	)
	flag.Parse()

	ips, err := getIpAddresses()
	if err != nil {
		log.Fatalf("Unable to get ip addresses: %v", err)
	}
	log.Printf("frontend begins: available interfaces: %s; addr= %q", strings.Join(ips, ", "), *addr)

	if err := run(*certFile, *keyFile, *addr, *backend, *allowInsecure); err != nil {
		log.Fatalf("run returned an error: %v", err)
	}

}
