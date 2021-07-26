ARG foundation_version=latest
FROM agogpixel/foundation:${foundation_version}

ARG foundation_version=latest
ARG source_socket=/var/run/docker-host.sock
ARG target_socket=/var/run/docker.sock

ENV FOUNDATION_VERSION="${foundation_version}"
ENV FOUNDATION_DFROMD_SOURCE_SOCKET="${source_socket}"
ENV FOUNDATION_DFROMD_TARGET_SOCKET="${target_socket}"

COPY install.sh /tmp/
RUN apk --update-cache upgrade && \
    bash /tmp/install.sh \
        "${FOUNDATION_VERSION}" \
        "${FOUNDATION_DFROMD_SOURCE_SOCKET}" \
        "${FOUNDATION_DFROMD_TARGET_SOCKET}" && \
    rm -f /tmp/install.sh
