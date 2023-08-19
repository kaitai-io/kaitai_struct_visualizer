FROM ruby:3.2

# Copy gem sources
COPY . /app

# Install ksc + Java + cleanup
RUN apt-get update \
       && /app/.build/restore-deb.sh \
       && rm -rf /var/lib/apt/lists/* ./kaitai-struct-compiler_0.10_all.deb

# Build and install gem
RUN cd /app \
      && gem build -o ksv.gem kaitai-struct-visualizer \
      && gem install ksv.gem

WORKDIR /share

ENTRYPOINT ["/usr/local/bundle/bin/ksv"]
