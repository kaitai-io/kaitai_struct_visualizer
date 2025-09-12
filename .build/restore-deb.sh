#!/bin/sh -ef

KSC_VERSION=0.11
KSC_DEB_FILE="kaitai-struct-compiler_${KSC_VERSION}_all.deb"

cd "$(dirname "$0")"/..

mkdir -p out
cd out
curl -fsSLO "https://github.com/kaitai-io/kaitai_struct_compiler/releases/download/$KSC_VERSION/$KSC_DEB_FILE"

apt-get update
apt-get -y install openjdk-21-jre-headless
apt-get -y install "./$KSC_DEB_FILE"
