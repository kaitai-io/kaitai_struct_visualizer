FROM ruby

COPY . /app
WORKDIR /app

RUN gem build -o ksv.gem kaitai-struct-visualizer \
      && gem install ksv.gem

ENTRYPOINT ["/usr/local/bundle/bin/ksv"]
