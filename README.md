# Microservice Example

This repo contains an example gRPC based microservice.

The example contains two services, named **frontend** and **backend**. They both
have gRPC APIS defined in apis/&lt;service&gt;/proto, and the both export REST api
endpoints as well, which we use for testing.

The first step is to install the protobuf compiler. The recommended method is to
install pre-compiled binaries from
https://grpc.io/docs/protoc-installation/#binary-install

After protoc is installed, the golang plugins must be installed :
<pre><code>
 $ export GO111MODULE=on  # Enable module mode
 $ go install google.golang.org/protobuf/cmd/protoc-gen-go google.golang.org/grpc/cmd/protoc-gen-go-grpc
</code/></pre>

To launch and test the backend use:
<pre><code>
 $ make containers
 $ docker run -it --rm --name backend -p 8101:443 backend --certfile=testdata/selfsigned.crt --keyfile=testdata/selfsigned.key --insecure
 $ # Test the back end using curl
 $ curl -v -X POST --insecure -w "\n" https://localhost:8101/v1/microserver/backend/process -d '{"input":"foo"}'
</code/></pre>

To launch and test the frontend, which requires the backend to be running, use:
<pre><code>
 $ make containers
 $ docker run -it --rm --name backend -p 8101:443 backend --certfile=testdata/selfsigned.crt --keyfile=testdata/selfsigned.key --insecure
 $ # When the container starts, it will list the IP address of its adapter. You
 $ # need to use it here.
 $ docker run -it --rm --name frontend -p 8100:443 frontend --backend "&lt;backend_ip&gt;:443" --certfile=testdata/selfsigned.crt --keyfile=testdata/selfsigned.key --insecure 
 $ # Test the front end using curl
 $ curl -v -X POST -w "\n" --insecure https://localhost:8100/v1/microserver/process -d '{"input":"foo"}'
</code/></pre>
