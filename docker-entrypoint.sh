#!/bin/bash
set -e

if [ "$1" = 'api-umbrella' ]; then
  echo "web:" >> /etc/api-umbrella/api-umbrella.yml
  echo "  admin:" >> /etc/api-umbrella/api-umbrella.yml
  echo "    initial_superusers:" >> /etc/api-umbrella/api-umbrella.yml
  echo "      - $ADMIN_EMAIL" >> /etc/api-umbrella/api-umbrella.yml
fi

exec "$@"
