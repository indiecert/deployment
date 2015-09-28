#!/bin/sh

# Script to deploy IndieCert on a Fedora >= 22 installation using DNF.

# update system
sudo dnf clean all
sudo dnf -y update

# enable COPR repos
sudo dnf -y copr enable fkooman/php-base
sudo dnf -y copr enable fkooman/indiecert

# install additional software
sudo dnf -y install mod_ssl php php-opcache php-fpm httpd vim-minimal telnet openssl

# install IndieCert
sudo dnf -y install indiecert-auth indiecert-enroll indiecert-oauth

# enable HTTPD and PHP-FPM on boot
sudo systemctl enable httpd
sudo systemctl enable php-fpm

# generate self signed SSL certificate
sudo openssl req -subj '/CN=indiecert.example' -new -x509 -nodes -out /etc/pki/tls/certs/indiecert.example.crt -keyout /etc/pki/tls/private/indiecert.example.key
sudo chmod 600 /etc/pki/tls/private/indiecert.example.key

# empty the default Apache config files
sudo -s 'echo "" > /etc/httpd/conf.d/indiecert-auth.conf'
sudo -s 'echo "" > /etc/httpd/conf.d/indiecert-enroll.conf'
sudo -s 'echo "" > /etc/httpd/conf.d/indiecert-oauth.conf'

# Set PHP timezone, to suppress errors in the log
sudo sed -i 's/;date.timezone =/date.timezone = UTC/' /etc/php.ini

#https://secure.php.net/manual/en/ini.core.php#ini.expose-php
sudo sed -i 's/expose_php = On/expose_php = Off/' /etc/php.ini
 
# Don't have Apache advertise all version details
# https://httpd.apache.org/docs/2.4/mod/core.html#ServerTokens
sudo echo 'ServerTokens ProductOnly' > /etc/httpd/conf.d/servertokens.conf

# disable the certificate check for use within the docker image, as there is
# no trusted certificate for "indiecert.example" so verification will fail...
sudo sed -i 's/;disableServerCertCheck/disableServerCertCheck/' /etc/indiecert-auth/config.ini

# enable Twig template cache
sudo sed -i 's/;templateCache/templateCache/' /etc/indiecert-auth/config.ini

# recommendation from https://php.net/manual/en/opcache.installation.php
sudo sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=60/' /etc/php.d/opcache.ini

# use the global httpd config file
sudo cp indiecert.example-httpd.conf /etc/httpd/conf.d/indiecert.example.conf

# Add CAcert as a valid CA (this is pointless here as we disable certificate
# check anyway in the next step, but for production we use this)
sudo cp CAcert.pem /etc/pki/ca-trust/source/anchors/CAcert.pem
sudo update-ca-trust

# Initialize DB and CA
sudo -u apache indiecert-auth-init-db
sudo -u apache indiecert-enroll-init-ca
sudo -u apache indiecert-oauth-init-db

# start HTTPD and PHP-FPM
sudo systemctl start php-fpm
sudo systemctl start httpd

# ALL DONE!
