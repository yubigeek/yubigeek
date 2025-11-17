#!/bin/bash

# Copy wp-config if it doesn't exist
if [ ! -f /var/www/html/wp-config-docker.php ]; then
    cp /tmp/wp-config-docker.php /var/www/html/wp-config.php
    chown www-data:www-data /var/www/html/wp-config.php
    chmod 400 /var/www/html/wp-config.php
fi

# Execute CMD
exec "$@"