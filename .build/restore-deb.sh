#!/bin/sh -ef

curl -fsSLO https://github.com/kaitai-io/kaitai_struct_compiler/releases/download/0.10/kaitai-struct-compiler_0.10_all.deb

apt-get -y install openjdk-17-jre-headless
apt-get -y install ./kaitai-struct-compiler_0.10_all.deb
