# Use the official PHP image as a base image
FROM php:8.3-fpm

# Install system dependencies and PHP extensions
RUN apt-get update \
   && apt-get install -y --no-install-recommends \
   nginx \
   supervisor \
   curl \
   gnupg2 \
   ca-certificates \
   zip unzip \
   libzip-dev \
   libpng-dev \
   libjpeg-dev \
   libfreetype6-dev \
   libonig-dev \
   libxml2-dev \
   libicu-dev \
   libmagickwand-dev \
   procps \
   && docker-php-ext-configure gd --with-jpeg --with-freetype \
   && docker-php-ext-install -j$(nproc) pdo_mysql mysqli mbstring exif intl xml zip gd opcache \
   && pecl install redis \
   && docker-php-ext-enable redis \
   && pecl install imagick \
   && docker-php-ext-enable imagick \
   && apt-get autoremove -y \
   && rm -rf /var/lib/apt/lists/*

# Working directory
WORKDIR /var/www/html

# Change ownership of the working directory
RUN chown -R www-data:www-data /var/www/html

# Remove default Nginx configuration and add custom configurations
RUN rm -f /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*

# Copy custom configuration files from .docker directory
COPY .docker/nginx/wordpress.conf /etc/nginx/conf.d/default.conf
COPY .docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY .docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY .docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Copy custom wp-config for Docker
COPY .wordpress/wp-config-docker.php /tmp/wp-config-docker.php

# Create entrypoint script
COPY .docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose port 80
EXPOSE 80

# Set up health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 CMD curl -f http://127.0.0.1/ || exit 1

# Use entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Start Supervisord to manage Nginx and PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]