#####################################
#
# Build container
# The most basic build for aqualinkd
#
# Build arg AQUALINKD_VERSION selects the upstream release (defaults to a
# pinned version below; set to "latest" to track newest).
#
#####################################

FROM debian:bookworm AS aqualinkd-build

#VOLUME ["/aqualinkd-build"]

RUN apt-get update && \
    apt-get -y install curl make gcc libsystemd-dev

# Seup working dir
RUN mkdir /home/AqualinkD
WORKDIR /home/AqualinkD

# Pin the AqualinkD source version for reproducible builds.
# Override at build time with --build-arg AQUALINKD_VERSION=vX.Y.Z,
# or set to "latest" to track the newest upstream release.
ARG AQUALINKD_VERSION=v3.1.0
RUN set -eux; \
    if [ "$AQUALINKD_VERSION" = "latest" ]; then \
        url="$(curl -fsSL https://api.github.com/repos/aqualinkd/AqualinkD/releases/latest \
               | grep '"tarball_url"' | cut -d'"' -f4)"; \
        [ -n "$url" ] || { echo "ERROR: could not resolve latest release (GitHub API rate limit?)" >&2; exit 1; }; \
    else \
        url="https://github.com/aqualinkd/AqualinkD/archive/refs/tags/${AQUALINKD_VERSION}.tar.gz"; \
    fi; \
    echo "Fetching AqualinkD from: $url"; \
    curl -fsSL "$url" | tar xz --strip-components=1

# Build aqualinkd
RUN make clean && \
    make container

#####################################
#
# Runtime container
#
#####################################

FROM debian:bookworm-slim AS aqualinkd

ARG AQUALINKD_VERSION

RUN apt-get update && \
    apt-get install -y cron curl socat jq && \
    apt-get clean

# Set cron to read local.d
RUN sed -i '/EXTRA_OPTS=.-l./s/^#//g' /etc/default/cron

# Add Open Container Initiative (OCI) annotations.
# See: https://github.com/opencontainers/image-spec/blob/main/annotations.md

LABEL org.opencontainers.image.title="AqualinkD"
LABEL org.opencontainers.image.url="https://hub.docker.com/repository/docker/aqualinkd/aqualinkd/general"
LABEL org.opencontainers.image.source="https://github.com/aqualinkd/AqualinkD"
LABEL org.opencontainers.image.documentation="https://github.com/aqualinkd/AqualinkD"
LABEL org.opencontainers.image.version=$AQUALINKD_VERSION


COPY --from=aqualinkd-build /home/AqualinkD/release/aqualinkd /usr/local/bin/aqualinkd                        
COPY --from=aqualinkd-build /home/AqualinkD/release/rs485mon /usr/local/bin/rs485mon
COPY --from=aqualinkd-build /home/AqualinkD/web/ /var/www/aqualinkd/
#COPY --from=aqualinkd-build /home/AqualinkD/release/aqualinkd.conf /etc/aqualinkd.conf
RUN mkdir -p /aquadconf
ADD ./config/aqexec-pre-impl.sh /usr/local/bin/aqexec-pre-impl.sh
RUN chmod +x /usr/local/bin/aqexec-pre-impl.sh

# Bake the config in two places:
#  - /etc/aqualinkd.conf           default used by aqualinkd-docker on first boot
#  - /etc/aqualinkd.conf.template  immutable pristine copy; aqexec-pre regenerates
#                                  the mounted config from this on every start.
ADD ./config/aqualinkd.conf /etc/aqualinkd.conf
ADD ./config/aqualinkd.conf /etc/aqualinkd.conf.template

# Ship our own container start script (single source of truth, no build-time
# network fetch from upstream master).
ADD ./config/aqualinkd-docker.cmd /usr/local/bin/aqualinkd-docker
RUN chmod +x /usr/local/bin/aqualinkd-docker

ADD ./config/aqualinkd-ts.sh /usr/local/bin/aqualinkd-ts
RUN chmod +x /usr/local/bin/aqualinkd-ts

# Healthcheck: web UI must respond AND the serial bridge (socat PTY) must exist.
# Catches the "web up but RS485 link dead" failure mode, not just a dead web server.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:80/ >/dev/null 2>&1 && [ -e /aquadconf/tty.Pool ] || exit 1

CMD ["sh", "-c", "/usr/local/bin/aqualinkd-ts"]
