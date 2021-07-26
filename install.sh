#!/bin/bash

# Derived from https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/docker-debian.sh.
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.

set -o errexit
set -o pipefail
set -o noclobber
set -o nounset
#set -o xtrace

readonly FOUNDATION_DFROMD_INSTALL_FOUNDATION_VERSION="${1}"
readonly FOUNDATION_DFROMD_INSTALL_SOURCE_SOCKET="${2:-"/var/run/docker-host.sock"}"
readonly FOUNDATION_DFROMD_INSTALL_TARGET_SOCKET="${3:-"/var/run/docker.sock"}"

readonly FOUNDATION_DFROMD_INSTALL_PACKAGES='docker docker-compose grep shadow socat'
readonly FOUNDATION_DFROMD_INSTALL_USERNAME="${FOUNDATION_USERNAME}"

foundation_dfromd_install_main() {
    foundation_dfromd_install_print_header
    foundation_dfromd_install_install_packages
    foundation_dfromd_install_add_users_to_docker_group
    foundation_dfromd_install_setup_dfromd
}

foundation_dfromd_install_print_header() {
    cat <<EOF
################################################################################
# agogopixel/foundation:${FOUNDATION_DFROMD_INSTALL_FOUNDATION_VERSION} Docker From Docker Installer
################################################################################
EOF
}

foundation_dfromd_install_install_packages() {
    printf '\nInstalling packages...\n'
    apk add --no-cache --update ${FOUNDATION_DFROMD_INSTALL_PACKAGES}
}

foundation_dfromd_install_add_users_to_docker_group() {
    local username="${FOUNDATION_DFROMD_INSTALL_USERNAME}"

    if [ "${username}" != root ]; then
        printf "\nAdding user '%s' to docker group...\n" "${username}"
        addgroup "${username}" docker
    fi

    printf "\nAdding user root to docker group...\n"
    addgroup root docker
}

foundation_dfromd_install_setup_dfromd() {
    printf "\nSetting up dfromd...\n"

    local src_sock="${FOUNDATION_DFROMD_INSTALL_SOURCE_SOCKET}"
    local trg_sock="${FOUNDATION_DFROMD_INSTALL_TARGET_SOCKET}"
    local username="${FOUNDATION_DFROMD_INSTALL_USERNAME}"
    local entrypoint="${FOUNDATION_ENTRYPOINTD_PATH}/dfromd.sh"

    # By default, make the source and target sockets the same.
    if [ "${src_sock}" != "${trg_sock}" ]; then
        touch "${src_sock}"
        ln -s "${src_sock}" "${trg_sock}"
    fi

    if [ "${username}" = root ]; then
        return
    fi

    chown -h "${username}":root "${trg_sock}"
    foundation_dfromd_install_get_dfromd_entrypoint > "${entrypoint}"
    chown "${username}":root "${entrypoint}"
}

foundation_dfromd_install_get_dfromd_entrypoint() {
    local SOURCE_SOCKET="${FOUNDATION_DFROMD_INSTALL_SOURCE_SOCKET}"
    local TARGET_SOCKET="${FOUNDATION_DFROMD_INSTALL_TARGET_SOCKET}"
    local USERNAME="${FOUNDATION_DFROMD_INSTALL_USERNAME}"

    cat <<EOF
#!/bin/bash

# Derived from https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/docker-debian.sh.
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.

set -o errexit
set -o pipefail
set -o noclobber
set -o nounset
#set -o xtrace

DFROMD_LOG=/var/log/dfromd-startup.log
DFROMD_PID=/run/dfromd.pid

# Wrapper function to only use sudo if not already root.
sudo_if() {
    if [ "\$(id -u)" -ne 0 ]; then
        sudo "\${@}"
    else
        "\${@}"
    fi
}

# Log messages.
log() {
    echo -e "[\$(date)] \$@" | sudo_if tee -a \${DFROMD_LOG} > /dev/null
}

log "Ensuring ${USERNAME} has access to ${SOURCE_SOCKET} via ${TARGET_SOCKET}"

# If enabled, try to add a docker group with the right GID. If the group is
# root, fall back on using socat to forward the docker socket to another unix
# socket so that we can set permissions on it without affecting the host.
if [ "${SOURCE_SOCKET}" != "${TARGET_SOCKET}" ] && [ "${USERNAME}" != "root" ] && [ "${USERNAME}" != "0" ]; then
    SOCKET_GID=\$(stat -c '%g' ${SOURCE_SOCKET})

    if [ "\${SOCKET_GID}" != "0" ]; then
        log "Adding user to group with GID \${SOCKET_GID}."

        if [ "\$(cat /etc/group | grep :\${SOCKET_GID}:)" = "" ]; then
            sudo_if addgroup -g \${SOCKET_GID} docker-host
        fi

        # Add user to group if not already in it.
        if [ "\$(id ${USERNAME} | grep -E 'groups=.+\${SOCKET_GID}\(')" = "" ]; then
            sudo_if addgroup ${USERNAME} docker-host
        fi
    else
        # Enable proxy if not already running.
        if [ ! -f "\${DFROMD_PID}" ] || ! ps -p \$(cat \${DFROMD_PID}) > /dev/null; then
            log "Enabling socket proxy."
            log "Proxying ${SOURCE_SOCKET} to ${TARGET_SOCKET}"

            sudo_if mkdir -p /etc/sv/dfromd
            sudo_if echo "$(foundation_dfromd_install_get_dfromd_service_run)" > /etc/sv/dfromd/run
            sudo_if chmod +x /etc/sv/dfromd/run
            sudo_if ln -s /etc/sv/dfromd "${FOUNDATION_SERVICE_PATH}"/dfromd
        else
            log "Socket proxy already running."
        fi
    fi

    log "Success"
fi
EOF

    # Support docker socket access when running as non-root user, no daemon.
    sed -i $'s/exec tini -- "${@}"/args="$(sed \'s\/"\/\\\\\\\\"\/g\' <<< "${@}")"; args="\"${args}\""; exec tini -- sg docker-host -c "${args}"/' "${FOUNDATION_ENTRYPOINT_PATH}"
}

foundation_dfromd_install_get_dfromd_service_run() {
    local SOURCE_SOCKET="${FOUNDATION_DFROMD_INSTALL_SOURCE_SOCKET}"
    local TARGET_SOCKET="${FOUNDATION_DFROMD_INSTALL_TARGET_SOCKET}"
    local USERNAME="${FOUNDATION_DFROMD_INSTALL_USERNAME}"

    cat <<EOF
#!/bin/sh
exec 2>&1
/bin/rm -rf ${TARGET_SOCKET}
exec /usr/sbin/socat -y -p dfromd UNIX-LISTEN:${TARGET_SOCKET},fork,mode=660,user=${USERNAME} UNIX-CONNECT:${SOURCE_SOCKET}
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    foundation_dfromd_install_main "${@}"
fi
