FROM debian:trixie-slim

RUN apt update &&\
 apt upgrade -y &&\
 apt install -y gzip vim apache2 subversion libapache2-mod-svn &&\
 mkdir --parents /var/lib/svn/repos &&\
 mkdir --parents /var/lib/svn/access &&\
 /usr/sbin/a2enmod dav dav_svn authz_svn &&\
 touch /var/lib/svn/access/svnpass && touch /var/lib/svn/access/svnauth

COPY settings/http/index.html /var/www/html/

RUN chown -R www-data:www-data /var/www/html

COPY settings/apache/dav_svn.conf /etc/apache2/mods-enabled/

COPY settings/apache/000-default.conf /etc/apache2/sites-enabled/

ENTRYPOINT [ "/usr/sbin/apachectl", "-D", "FOREGROUND" ]
