FROM ruby

# Install .ksy compiler
RUN apt-key adv --keyserver hkp://pool.sks-keyservers.net --recv 379CE192D401AB61 \
       && echo "deb https://dl.bintray.com/kaitai-io/debian jessie main" | tee /etc/apt/sources.list.d/kaitai.list \
       && apt-get update \
       && apt-get install kaitai-struct-compiler \
       && rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app

RUN gem build -o ksv.gem kaitai-struct-visualizer \
      && gem install ksv.gem

ENTRYPOINT ["/usr/local/bundle/bin/ksv"]
