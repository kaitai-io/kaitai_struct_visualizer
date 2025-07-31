FROM ruby:3.4

# Copy gem sources
COPY . /app

# Install ksc + Java + cleanup
RUN /app/.build/restore-deb.sh \
    && rm -rf /var/lib/apt/lists/*

# Build and install gem
RUN cd /app \
    && gem build -o ksv.gem kaitai-struct-visualizer \
    && gem install ksv.gem

WORKDIR /share

ENTRYPOINT ["/usr/local/bundle/bin/ksv"]
