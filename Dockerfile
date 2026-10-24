FROM debian:trixie-slim

RUN apt-get update &&\
 apt-get upgrade -y &&\
 apt-get install -y --no-install-recommends gzip vim apache2 subversion libapache2-mod-svn &&\
 rm -rf /var/lib/apt/lists/* &&\
 install -d -o www-data -g www-data /var/lib/svn/repos &&\
 install -d -m 0750 -g www-data /var/lib/svn/access &&\
 /usr/sbin/a2enmod dav dav_svn authz_svn &&\
 touch /var/lib/svn/access/svnpass /var/lib/svn/access/svnauth &&\
 chown root:www-data /var/lib/svn/access/svnpass /var/lib/svn/access/svnauth &&\
 chmod 0640 /var/lib/svn/access/svnpass /var/lib/svn/access/svnauth

COPY settings/apache/dav_svn.conf /etc/apache2/mods-enabled/

COPY settings/apache/000-default.conf /etc/apache2/sites-enabled/

COPY settings/apache/container.conf /etc/apache2/conf-enabled/

ENTRYPOINT [ "/usr/sbin/apachectl", "-D", "FOREGROUND" ]
