#! /bin/bash

if [ $# -ne 1 ]
then
  echo "usage: $0 <path_to_proto_file>" 1>&2
  exit 1
fi

PROTO_PATH="$1"
PROTO_DIR=$(dirname "${PROTO_PATH}")

# Because we are using go modules, this incantation is required to find the
# google apis proto.
ANNOTATIONS_DIR=$(go list -m -f "{{.Dir}}" github.com/grpc-ecosystem/grpc-gateway)/third_party/googleapis

protoc -I "${PROTO_DIR}" -I "${ANNOTATIONS_DIR}" --go_out=plugins=grpc:"${PROTO_DIR}" "${PROTO_PATH}"
protoc -I "${PROTO_DIR}" -I "${ANNOTATIONS_DIR}" --grpc-gateway_out=logtostderr=true:"${PROTO_DIR}" "${PROTO_PATH}"
