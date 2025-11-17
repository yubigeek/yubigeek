#!/bin/bash

# Copy wp-config if it doesn't exist
if [ ! -f /var/www/html/wp-config-docker.php ]; then
    cp /tmp/wp-config-docker.php /var/www/html/wp-config-docker.php
    chown www-data:www-data /var/www/html/wp-config-docker.php
fi

# Execute CMD
exec "$@"