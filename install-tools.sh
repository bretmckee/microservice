#! /bin/bash
set -euo pipefail

if [ ${EUID} != 0 ]
then
	echo usage "Must be run with euid 0, not ${EUID}" 2>&1
	exit 1
fi

echo "Installing for arch $(uname -m)"
PROTOC_ARCH=x86_64

# The protoc distribution does not name architectues the same as either Ubuntu or dpkg,
# so this case is neeeded to determine the right version.
if [ $(uname -m) == "aarch64" ]; then
    PROTOC_ARCH=aarch_64
fi

PROTOC_URL="https://github.com/google/protobuf/releases/download/v3.13.0/protoc-3.13.0-linux-${PROTOC_ARCH}.zip"
if /usr/local/bin/protoc --version > /dev/null 2>&1; then
	echo "skipping already installed /usr/local/bin/protoc"
else
	echo "Installing protoc from ${PROTOC_URL}"
	PROTOC_ZIP="$(mktemp)-protoc.zip"
	# There is a race here -- if we get interrupted or there is an error we can
	# strand the file in /tmp. Since /tmp gets cleaned up, it doesn't seem worth
	# the extra effort to try an clean it up here.
	curl -sSL ${PROTOC_URL} -o ${PROTOC_ZIP}
	unzip -o ${PROTOC_ZIP} -x readme.txt -d /usr/local
	rm ${PROTOC_ZIP}

	chmod -R 555 /usr/local/include/google /usr/local/bin/protoc
fi

GO_URL="https://golang.org/dl/go1.19.7.linux-$(dpkg --print-architecture).tar.gz"
if /usr/local/go/bin/go version > /dev/null 2>&1; then
	echo "skipping already installed /usr/local/go/bin/go"
else
	echo "Installing golang"
	curl -sSL ${GO_URL} | tar -C /usr/local -xzf -
fi
