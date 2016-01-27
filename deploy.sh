#!/bin/sh

# Script to deploy IndieCert on a Fedora >= 22 installation using DNF.
# Tested on Fedora 23

###############################################################################
# VARIABLES
###############################################################################

# VARIABLES
HOSTNAME=indiecert.example

###############################################################################
# SYSTEM
###############################################################################

sudo dnf -y update

# enable COPR repos
sudo dnf -y copr enable fkooman/php-base
sudo dnf -y copr enable fkooman/indiecert

# install software
sudo dnf -y install mod_ssl php php-opcache php-fpm httpd indiecert-auth indiecert-demo

###############################################################################
# CERTIFICATE
###############################################################################

# Generate the private key
sudo openssl genrsa -out /etc/pki/tls/private/${HOSTNAME}.key 2048
sudo chmod 600 /etc/pki/tls/private/${HOSTNAME}.key

# Update the config file
sudo cp indiecert.example.cnf ${HOSTNAME}.cnf
sudo sed -i "s/indiecert.example/${HOSTNAME}/" ${HOSTNAME}.cnf

# Create the CSR (can be used to obtain real certificate!)
sudo openssl req -sha256 -new    -reqexts v3_req -config ${HOSTNAME}.cnf       -key /etc/pki/tls/private/${HOSTNAME}.key -out ${HOSTNAME}.csr

# Create the (self signed) certificate and install it
sudo openssl req -sha256 -new -extensions v3_req -config ${HOSTNAME}.cnf -x509 -key /etc/pki/tls/private/${HOSTNAME}.key -out /etc/pki/tls/certs/${HOSTNAME}.crt

###############################################################################
# APACHE
###############################################################################

# empty the default Apache config files
sudo sh -c 'echo "" > /etc/httpd/conf.d/indiecert-auth.conf'
sudo sh -c 'echo "" > /etc/httpd/conf.d/indiecert-demo.conf'

# use the httpd config files
sudo cp indiecert.example-httpd.conf /etc/httpd/conf.d/${HOSTNAME}.conf
sudo cp demo.indiecert.example-httpd.conf /etc/httpd/conf.d/demo.${HOSTNAME}.conf

sudo sed -i "s/indiecert.example/${HOSTNAME}/" /etc/httpd/conf.d/${HOSTNAME}.conf
sudo sed -i "s/indiecert.example/${HOSTNAME}/" /etc/httpd/conf.d/demo.${HOSTNAME}.conf

# Don't have Apache advertise all version details
# https://httpd.apache.org/docs/2.4/mod/core.html#ServerTokens
sudo sh -c 'echo "ServerTokens ProductOnly" > /etc/httpd/conf.d/servertokens.conf'

###############################################################################
# PHP
###############################################################################

# Set PHP timezone, to suppress errors in the log
sudo sed -i 's/;date.timezone =/date.timezone = UTC/' /etc/php.ini

#https://secure.php.net/manual/en/ini.core.php#ini.expose-php
sudo sed -i 's/expose_php = On/expose_php = Off/' /etc/php.ini
 
# recommendation from https://php.net/manual/en/opcache.installation.php
sudo sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=60/' /etc/php.d/10-opcache.ini

# PHP-FPM configuration
# XXX: use socket instead?
sudo sed -i "s|listen = /run/php-fpm/www.sock|listen = [::]:9000|" /etc/php-fpm.d/www.conf
sudo sed -i "s/listen.allowed_clients = 127.0.0.1/listen.allowed_clients = 127.0.0.1,::1/" /etc/php-fpm.d/www.conf

###############################################################################
# APP
###############################################################################

# indiecert-auth
sudo sed -i "s/indiecert.example/${HOSTNAME}/" /etc/indiecert-auth/config.yaml

# indiecert-demo
sudo sed -i "s/indiecert.example/${HOSTNAME}/" /etc/indiecert-demo/config.yaml
sudo sed -i 's/serverMode: production/serverMode: development/' /etc/indiecert-demo/config.yaml

# enable Twig template cache
sudo sed -i 's/#templateCache/templateCache/' /etc/indiecert-auth/config.yaml
sudo sed -i 's/#templateCache/templateCache/' /etc/indiecert-demo/config.yaml

# Initialize DB and CA
sudo -u apache indiecert-auth-init
sudo -u apache indiecert-auth-init-ca

###############################################################################
# DAEMONS
###############################################################################

# enable HTTPD and PHP-FPM on boot
sudo systemctl enable httpd
sudo systemctl enable php-fpm

# start HTTPD and PHP-FPM
sudo systemctl start php-fpm
sudo systemctl start httpd

# ALL DONE!
