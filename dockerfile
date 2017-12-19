#!/usr/bin/env bash
FROM debian:jessie

MAINTAINER Clickbus México "it@clickbus.com.mx"

# Settings
ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_VERSION 1.12.2-1~jessie
ENV TERM=linux
RUN echo export TERM=linux >> ~/.bashrc

# Install Basic packages
RUN apt-get update \
    && apt-get install --assume-yes --no-install-recommends \
      ca-certificates locales wget git curl zip vim python-pip apt-utils make net-tools cron htop ruby-full \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Ensure UTF-8
RUN dpkg-reconfigure locales && \
    locale-gen C.UTF-8 && \
    /usr/sbin/update-locale LANG=C.UTF-8

# Prevent restarts when installing
RUN echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d && /bin/chmod +x /usr/sbin/policy-rc.d

## MySQL Client.

RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y mysql-client \
	&& rm -rf /var/lib/apt/lists/*

## PHP 7.0.

# Install dotdeb repo, PHP7, composer and selected extensions
RUN echo "deb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list \
    && curl -sS https://www.dotdeb.org/dotdeb.gpg | apt-key add - \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        php7.0 php7.0-cgi php7.0-fpm php7.0-cli php7.0-apcu php7.0-apcu-bc \
        php7.0-xsl php7.0-common php7.0-json php7.0-opcache php7.0-mysql \
        php7.0-phpdbg php7.0-intl php7.0-gd php7.0-imap php7.0-mcrypt \
        php7.0-readline php7.0-ldap php7.0-pgsql php7.0-pspell php7.0-recode \
        php7.0-tidy php7.0-dev php7.0-curl php7.0-xml php7.0-zip php7.0-dom php7.0-mbstring \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* ~/.composer

# Create socket
RUN mkdir -p /run/php \
    && touch /run/php/php7.0-fpm.sock \
    && /bin/chown www-data:www-data /run/php/php7.0-fpm.sock \
    && /bin/chmod +x /run/php/php7.0-fpm.sock

# Configure FPM to run properly on docker
RUN usermod -u 1000 www-data

## UploadProgress

# @see: https://www.xandermar.com/solved-how-install-uploadprogress-php-7-centosrhel-drupal
RUN cd ~/ \
    && git clone https://github.com/Jan-E/uploadprogress \
    && cd uploadprogress/ \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && echo "extension=uploadprogress.so" >> /etc/php/7.0/fpm/conf.d/20-uploadprogress.ini

## PHP Unit

# Install phpunit
RUN wget https://phar.phpunit.de/phpunit.phar \
    && /bin/chmod +x phpunit.phar \
    && mv phpunit.phar /usr/local/bin/phpunit \
    && phpunit --version

## Drush

RUN composer global require drush/drush:8.* \
    && echo export PATH="$HOME/.composer/vendor/bin:/usr/sbin:$PATH" >> ~/.bashrc

## Drupal Console

RUN composer global require drupal/console:@stable \
    && echo "PATH=$PATH:~/.composer/vendor/bin" >> ~/.bash_profile

## Nginx.

# Install Nginx
RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
	&& echo "deb http://nginx.org/packages/debian/ jessie nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						nginx=${NGINX_VERSION} \
						nginx-module-xslt \
						nginx-module-geoip \
						nginx-module-image-filter \
						nginx-module-perl \
						nginx-module-njs \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/*

# Prepare DocumentRoot
RUN mkdir -p /var/www \
    && usermod -u 1000 www-data \
    && usermod -a -G users www-data \
    && usermod -a -G users root \
    && /bin/chown -R www-data:www-data /var/www

## SASS compass

RUN gem update --system \
    && gem install compass sass \
    && sass -v



# VirtualHost
COPY ./config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./config/nginx/nginx.default.conf /etc/nginx/conf.d/default.conf

## Supervisor

# Install supervisor
RUN pip install supervisor \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /var/run/supervisord


# VirtualHost
COPY ./config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./config/nginx/nginx.default.conf /etc/nginx/conf.d/default.conf
# Add supervisord conf
COPY ./config/supervisor/supervisord.conf /etc/supervisord.conf
# Setup PHP 7.0 FPM
COPY ./config/php-fpm/php-fpm.conf /etc/php/7.0/fpm/php-fpm.conf
COPY ./config/php-fpm/php-fpm.www.conf /etc/php/7.0/fpm/pool.d/www.conf
COPY ./config/php-fpm/php.ini /etc/php/7.0/fpm/php.ini

VOLUME /var-www
VOLUME /opt/ci
## Entrypoint: execution shell on run container
COPY ./config/entrypoint.sh /entrypoint.sh
RUN /bin/chmod 775 /entrypoint.sh

CMD ["/usr/local/bin/supervisord", "-n"]

COPY ./cbmx_landing_pages /var/www
VOLUME ./cbmx_landing_pages /var/www
WORKDIR /var/www

RUN /var/www/composer install

EXPOSE 80




