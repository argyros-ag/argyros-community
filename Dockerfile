FROM alpine:3.20

RUN apk add --no-cache ca-certificates wget

# VERSION and TARGETARCH are set by the publish.yml build-args + Docker Buildx
ARG VERSION
ARG TARGETARCH

# Download pre-built binaries from the GitHub Release for this version.
# TARGETARCH is "amd64" or "arm64" — matches our release asset naming.
RUN wget -q \
      "https://github.com/argyros-ag/argyros-community/releases/download/${VERSION}/argyros-community-linux-${TARGETARCH}" \
      -O /usr/local/bin/argyros-community && \
    chmod +x /usr/local/bin/argyros-community

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/argyros-community"]
