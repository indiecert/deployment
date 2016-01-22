# Introduction

This is the deployment repository of IndieCert.

# Usage

On a Fedora 23 clean install:

    $ curl -L -O https://github.com/indiecert/deployment/archive/master.tar.gz
    $ tar -xzf master.tar.gz
    $ cd deployment-master

Modify the `HOSTNAME` in `deploy.sh` and set it to your hostname.

    $ sh deploy.sh

# Let's Encrypt

    $ sudo dnf -y install letsencrypt
    $ sudo letsencrypt certonly

... TBD

