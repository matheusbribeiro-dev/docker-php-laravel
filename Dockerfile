FROM php:8.1.7-apache-bullseye

ARG user
ARG uid

ENV ACCEPT_EULA=Y

RUN a2enmod ssl \
    && a2enmod rewrite

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    apt-transport-https \
    software-properties-common \
    openssl \
    apt-utils \
    autoconf \
    unixodbc \
    unixodbc-dev \
    libltdl-dev \
    build-essential \
    procps \
    file \
    libxml2 \
    unzip \
    gnupg2 \
    git \
    curl \
    libtool \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libmcrypt-dev \
    libbz2-dev \
    libzip-dev \
    libmagickwand-dev \
    libmagickcore-dev \
    libsodium-dev \
    zip \
    bzr \
    cvs \
    subversion \
    wget \
    libldap2-dev \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# NVM for install node lts version
ENV NVM_DIR /usr/local/nvm
RUN mkdir $NVM_DIR
ENV NODE_VERSION 18.14.0

# install nvm
# https://github.com/creationix/nvm#install-script
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

# install node and npm
RUN echo "source $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default" | bash

# add node and npm to path so the commands are available
ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Install prerequisites for the sqlsrv and pdo_sqlsrv PHP extensions.
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && apt-get install -y msodbcsql17 mssql-tools \
    && rm -rf /var/lib/apt/lists/*

#Install composer
RUN wget -O composer-setup.php https://getcomposer.org/installer \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && chmod +x /usr/local/bin/composer

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql mbstring xml exif pcntl bcmath gd \
    sodium zip bcmath soap opcache ldap \ 
    && pecl install xdebug \ 
    && docker-php-ext-enable xdebug \
    && rm -rf /var/lib/apt/lists/*

# Retrieve the script used to install PHP extensions from the source container.
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/install-php-extensions

# PHP extensions and all their prerequisites available via apt.
RUN chmod uga+x /usr/bin/install-php-extensions \ 
   && sync \
   && install-php-extensions sqlsrv pdo_sqlsrv intl grpc xmlrpc imagick  \
   && rm -rf /var/lib/apt/lists/*

# Create system user to run Composer and Artisan Commands
RUN useradd -G www-data,root -u $uid -d /home/$user $user
RUN mkdir -p /home/$user/.composer && \
    chown -R $user:$user /home/$user

WORKDIR /var/www/html

COPY ./config/apache/000-default.conf /etc/apache2/sites-enabled/000-default.conf
COPY ./config/xdebug/99-xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini

USER $user

CMD ["apachectl", "-D", "FOREGROUND"]