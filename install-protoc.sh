#! /bin/bash 
set -euxo pipefail                                                                                                                                                                                                   

if [ ${EUID} != 0 ]
then
usage "Must be run with euid 0, not ${EUID}"
fi

echo "Installing for arch $(uname -m)"
PROTOC_ARCH=x86_64

# The protoc distribution does not name architectues the same as either Ubuntu or dpkg,
# so this case is neeeded to determine the right version.
if [ $(uname -m) == "aarch64" ]; then
    PROTOC_ARCH=aarch_64
fi

PROTOC_URL="https://github.com/google/protobuf/releases/download/v3.13.0/protoc-3.13.0-linux-${PROTOC_ARCH}.zip"
echo "Installing protoc from ${PROTOC_URL}"
PROTOC_ZIP="$(mktemp)-protoc.zip"                                                                                                                                                                                    
# There is a race here -- if we get interrupted or there is an error we can                                                                                                                                          
# strand the file in /tmp. Since /tmp gets cleaned up, it doesn't seem worth                                                                                                                                         
# the extra effort to try an clean it up here.                                                                                                                                                                       
curl -sSL ${PROTOC_URL} -o ${PROTOC_ZIP}                                                                                                                                                                             
unzip -o ${PROTOC_ZIP} -x readme.txt bin/protoc -d /usr/local                                                                                                                                                                      
rm ${PROTOC_ZIP}                                                                                                                                                                                                     

chmod -R 555 /usr/local/include/google /usr/local/bin/protoc   
