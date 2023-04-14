#! /bin/bash
set -euo pipefail

if type go > /dev/null 2>&1; then
	GO_CACHE=$(go env GOCACHE)
else
	GO_CACHE=${HOME}/.cache/go-build
fi
GO_PKG_DIR=${GOPATH:-${HOME}/go}/pkg

mkdir -p ${GO_CACHE} ${GO_PKG_DIR}

docker run -it --rm --user=$(id -u):$(id -g) \
  --group-add $(getent group docker | cut -d: -f3) \
  -v ${GO_PKG_DIR}:/go/pkg \
  -v ${GO_CACHE}:/.cache/go-build \
  -v /var/run/docker.sock:/var/run/docker.sock:rw \
  -v $(pwd):/go/src \
  microservice-base $@
