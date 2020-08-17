FROM php:7.4-fpm-alpine3.11 as php

ARG PHP_EXTENSION_EXTRA="ffi"

ARG PECL_EXTENSION_EXTRA

ARG APK_EXTRA

ARG APK_DEV_EXTRA

ENV APP_ENV=development

ENV PHP_EXTENSION \
      bcmath \
      bz2 \
      calendar \
      enchant \
      exif \
      gd \
      gettext \
      gmp \
      imap \
      intl \
      mysqli \
      pcntl \
      pdo_pgsql \
      pdo_mysql \
      pgsql \
      sockets \
      sysvmsg \
      sysvsem \
      sysvshm \
      # tidy \
      # xmlrpc \
      # xsl \
      zip \
      shmop \
      ${PHP_EXTENSION_EXTRA:-}

ENV PECL_EXTENSION \
      igbinary \
      redis \
      memcached \
      xdebug-2.9.6 \
# 安装测试版的扩展，可以在扩展名后加 -beta
      # xdebug-2.9.6 \
      ${PECL_EXTENSION_EXTRA:-}

ARG ALPINE_URL=dl-cdn.alpinelinux.org

RUN sed -i "s/dl-cdn.alpinelinux.org/${ALPINE_URL}/g" /etc/apk/repositories \
      && set -xe \
# 不要删除
      && PHP_FPM_RUN_DEPS=" \
                         bash \
                         tzdata \
                         libmemcached-libs \
                         libpq \
                         libzip \
                         zlib \
                         libpng \
                         freetype \
                         libjpeg-turbo \
                         libxpm \
                         libwebp \
                         libbz2 \
                         libexif \
                         gmp \
                         # xmlrpc-c \
                         enchant \
                         c-client \
                         icu-libs \
                         gnu-libiconv \
                         ${APK_EXTRA:-} \
                         " \
                         # tidyhtml-libs \
                         # libxslt \
# *-dev 编译之后删除
      && PHP_FPM_BUILD_DEPS=" \
                         openssl-dev \
                         libmemcached-dev \
                         cyrus-sasl-dev \
                         postgresql-dev \
                         libzip-dev \
                         zlib-dev \
                         libpng-dev \
                         freetype-dev \
                         libjpeg-turbo-dev \
                         libxpm-dev \
                         libwebp-dev \
                         libexif-dev \
                         gmp-dev \
                         # xmlrpc-c-dev \
                         bzip2-dev \
                         enchant-dev \
                         imap-dev \
                         gettext-dev \
                         libwebp-dev \
                         icu-dev \
                         ${APK_DEV_EXTRA:-} \
                         " \
                         # tidyhtml-dev \
                         # libxslt-dev \
        && apk add --no-cache --virtual .php-fpm-run-deps $PHP_FPM_RUN_DEPS \
        && apk add --no-cache --virtual .php-fpm-build-deps $PHP_FPM_BUILD_DEPS patch \
        && apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS \
        && curl -fsSL -o /usr/local/bin/pickle \
           https://github.com/khs1994-php/pickle/releases/download/nightly/pickle-debug.phar \
        && chmod +x /usr/local/bin/pickle \
# 安装内置扩展
        && docker-php-source extract \
# enchant-2.patch
        && cd /usr/src/php \
        && curl -fsSL -o enchant-2.patch https://git.alpinelinux.org/aports/plain/community/php7/enchant-2.patch?id=f09d70c946d9953ab11d45e4345ecd6705c1903c \
#        && patch -p1 < enchant-2.patch \
        && rm -rf enchant-2.patch \
#        && ./buildconf --force \
        && cd - \
        \
        && docker-php-ext-configure zip \
                                    --with-zip \
        && docker-php-ext-install zip \
        && strip --strip-all $(php-config --extension-dir)/zip.so \
        # && docker-php-ext-configure gd \
        && echo " \
                                        --disable-gd-jis-conv \
                                        --with-freetype \
                                        --with-jpeg \
                                        --with-webp \
                                        --with-xpm" > /tmp/gd.configure.options \
        # && docker-php-ext-install $PHP_EXTENSION \
        && pickle install $PHP_EXTENSION -n --defaults --strip \
        && docker-php-source delete \
# 安装 PECL 扩展
        && echo "--enable-redis-igbinary" > /tmp/redis.configure.options \
        && echo "--enable-memcached-igbinary" > /tmp/memcached.configure.options \
        && pickle install $PECL_EXTENSION -n --defaults \
           --strip --cleanup \
# 默认不启用的扩展
        && pickle install \
             xdebug \
# https://github.com/tideways/php-xhprof-extension.git
             https://github.com/tideways/php-xhprof-extension/archive/master.tar.gz \
             -n --defaults --strip --cleanup --no-write \
        && pickle install opcache \
        # && docker-php-ext-enable opcache \
        && apk del --no-network .phpize-deps .php-fpm-build-deps \
        && rm -rf /tmp/* \
# 创建日志文件夹
        && mkdir -p /var/log/php-fpm \
        && ln -sf /dev/stdout /var/log/php-fpm/access.log \
        && ln -sf /dev/stderr /var/log/php-fpm/error.log \
        && ln -sf /dev/stderr /var/log/php-fpm/xdebug-remote.log \
        && chmod -R 777 /var/log/php-fpm \
        && rm -rf /usr/local/lib/php/.registry/.channel.pecl.php.net/* \
        && php -m \
        && ls -la $(php-config --extension-dir) \
        && LD_PRELOAD="/usr/lib/preloadable_libiconv.so php" php -d error_reporting=22527 -d display_errors=1 -r 'var_dump(iconv("UTF-8", "UTF-8//IGNORE", "This is the Euro symbol '\''€'\''."));'

ENV LD_PRELOAD="/usr/lib/preloadable_libiconv.so php"

WORKDIR /var/www/html

ARG VCS_REF="unknow"

LABEL org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.source="https://github.com/khs1994-docker/php"

RUN docker-php-ext-enable xdebug

# Add UID '1000' to www-data
RUN apk add shadow && usermod -u 1000 www-data && groupmod -g 1000 www-data

# Copy existing application directory permissions
COPY --chown=www-data:www-data . /var/www/html

# Change current user to www
USER www-data