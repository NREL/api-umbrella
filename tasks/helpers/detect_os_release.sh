#!/usr/bin/env bash
# shellcheck disable=SC2034

detect_os_release() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
  elif [ -f /etc/redhat-release ]; then
    if [ -f /etc/centos-release ]; then
      ID="centos"
      ID_LIKE="rhel fedora"
    else
      ID="rhel"
      ID_LIKE="fedora"
    fi

    VERSION_ID="$(grep -oP '(?<= )[0-9]+(?=\.)' /etc/redhat-release)"
  fi

  if [[ "$ID" == "rhel" || " ${ID_LIKE:-} " == *" rhel "* ]]; then
    ID_NORMALIZED="rhel"
  elif [[ "$ID" == "debian" || " ${ID_LIKE:-} " == *" debian "* ]]; then
    ID_NORMALIZED="debian"
  fi
}
