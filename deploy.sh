#!/bin/sh

# Script to deploy IndieCert on a Fedora >= 22 installation using DNF.
# Tested on Fedora 23 Beta.

# VARIABLES
HOSTNAME=indiecert.example

# update system
sudo dnf clean all
sudo dnf -y update

# set hostname
sudo hostnamectl set-hostname ${HOSTNAME}

# enable COPR repos
sudo dnf -y copr enable fkooman/php-base
sudo dnf -y copr enable fkooman/indiecert

# install additional software
sudo dnf -y install mod_ssl php php-opcache php-fpm httpd vim-minimal telnet openssl

# install IndieCert
sudo dnf -y install indiecert-auth indiecert-enroll indiecert-oauth

# generate self signed SSL certificate
sudo openssl req -subj "/CN=${HOSTNAME}" -new -x509 -nodes -out /etc/pki/tls/certs/${HOSTNAME}.crt -keyout /etc/pki/tls/private/${HOSTNAME}.key
sudo chmod 600 /etc/pki/tls/private/${HOSTNAME}.key

# empty the default Apache config files
sudo sh -c 'echo "" > /etc/httpd/conf.d/indiecert-auth.conf'
sudo sh -c 'echo "" > /etc/httpd/conf.d/indiecert-enroll.conf'
sudo sh -c 'echo "" > /etc/httpd/conf.d/indiecert-oauth.conf'

# Set PHP timezone, to suppress errors in the log
sudo sed -i 's/;date.timezone =/date.timezone = UTC/' /etc/php.ini

#https://secure.php.net/manual/en/ini.core.php#ini.expose-php
sudo sed -i 's/expose_php = On/expose_php = Off/' /etc/php.ini
 
# Don't have Apache advertise all version details
# https://httpd.apache.org/docs/2.4/mod/core.html#ServerTokens
sudo sh -c 'echo "ServerTokens ProductOnly" > /etc/httpd/conf.d/servertokens.conf'

# disable the certificate check for now, as there is no trusted certificate 
# for "${HOSTNAME}" so verification will fail...
sudo sed -i 's/;disableServerCertCheck/disableServerCertCheck/' /etc/indiecert-auth/config.ini

# enable Twig template cache
sudo sed -i 's/;templateCache/templateCache/' /etc/indiecert-auth/config.ini
sudo sed -i 's/;templateCache/templateCache/' /etc/indiecert-enroll/config.ini
sudo sed -i 's/;templateCache/templateCache/' /etc/indiecert-oauth/server.ini

# recommendation from https://php.net/manual/en/opcache.installation.php
sudo sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=60/' /etc/php.d/10-opcache.ini

# use the global httpd config file
sudo cp indiecert.example-httpd.conf /etc/httpd/conf.d/${HOSTNAME}.conf
sudo sed -i "s/indiecert.example/${HOSTNAME}/" /etc/httpd/conf.d/${HOSTNAME}.conf

# PHP-FPM configuration
# XXX: use socket instead?
sudo sed -i "s|listen = /run/php-fpm/www.sock|listen = [::]:9000|" /etc/php-fpm.d/www.conf
sudo sed -i "s/listen.allowed_clients = 127.0.0.1/listen.allowed_clients = 127.0.0.1,::1/" /etc/php-fpm.d/www.conf

# Add CAcert as a valid CA (this is pointless here as we disable certificate
# check anyway in the next step, but for production we use this)
sudo cp CAcert.pem /etc/pki/ca-trust/source/anchors/CAcert.pem
sudo update-ca-trust

# Initialize DB and CA
sudo -u apache indiecert-auth-init-db
sudo -u apache indiecert-enroll-init-ca
sudo -u apache indiecert-oauth-init-db

# enable HTTPD and PHP-FPM on boot
sudo systemctl enable httpd
sudo systemctl enable php-fpm

# start HTTPD and PHP-FPM
sudo systemctl start php-fpm
sudo systemctl start httpd

# ALL DONE!
