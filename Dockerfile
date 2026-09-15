# Debian official multi-architecture index, captured 2026-09-13.
FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171 AS toolchain

# Snapshot fixes transitive packages too. APT signatures remain mandatory;
# only expiry is disabled for the immutable historical package index.
RUN rm -f /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260901T000000Z/ bookworm main' > /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       fp-compiler-3.2.2=3.2.2+dfsg-20 make python3 gcc libc6-dev \
       libsdl2-2.0-0 libsdl2-ttf-2.0-0 fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
ENV LANG=C.UTF-8 TERM=xterm-256color

FROM toolchain AS build
COPY Makefile chess.pas ChessCLI.pas ./
COPY src/ src/
COPY tests/ tests/
RUN make local-build local-test

FROM build AS test
CMD ["make", "local-test", "local-smoke"]

FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171 AS game
COPY --from=build /work/build/ChessCLI /usr/local/bin/ChessCLI
USER 65532:65532
ENV LANG=C.UTF-8 TERM=xterm-256color
ENTRYPOINT ["/usr/local/bin/ChessCLI"]
