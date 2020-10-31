FROM ruby

# Install .ksy compiler and Java
RUN apt-key adv --keyserver hkp://pool.sks-keyservers.net --recv 379CE192D401AB61 \
       && echo "deb https://dl.bintray.com/kaitai-io/debian jessie main" | tee /etc/apt/sources.list.d/kaitai.list \
       && apt-get update \
       && apt-get -y install kaitai-struct-compiler \
       && apt-get -y install openjdk-11-jre-headless \
       && rm -rf /var/lib/apt/lists/*

# Copy gem sources
COPY . /app

# Build and install gem
RUN cd /app \
      && gem build -o ksv.gem kaitai-struct-visualizer \
      && gem install ksv.gem

WORKDIR /share

ENTRYPOINT ["/usr/local/bundle/bin/ksv"]
