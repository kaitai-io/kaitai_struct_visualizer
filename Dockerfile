FROM ruby:3.2

# Download Kaitai Struct compiler deb
RUN curl -fsSLO https://github.com/kaitai-io/kaitai_struct_compiler/releases/download/0.10/kaitai-struct-compiler_0.10_all.deb

# Install it + Java + cleanup
RUN apt-get update \
       && apt-get -y install openjdk-17-jre-headless \
       && apt-get -y install ./kaitai-struct-compiler_0.10_all.deb \
       && rm -rf /var/lib/apt/lists/* ./kaitai-struct-compiler_0.10_all.deb

# Copy gem sources
COPY . /app

# Build and install gem
RUN cd /app \
      && gem build -o ksv.gem kaitai-struct-visualizer \
      && gem install ksv.gem

WORKDIR /share

ENTRYPOINT ["/usr/local/bundle/bin/ksv"]
