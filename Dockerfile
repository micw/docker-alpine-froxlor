FROM alpine:3.8


RUN export FROXLOR_VERSION=0.9.39.5 && \
    apk add --update --no-cache \
      curl tar supervisor html2text bash \
      apache2 php7-apache2 php7-cli php7-cgi mysql-client php7-session php-simplexml php7-ctype\
      php7-zip php7-pdo_mysql php7-xml php7-posix php7-mbstring php7-bcmath php7-json php7-curl \
      && \
    rm -rf /var/www/localhost/cgi-bin/* /var/www/localhost/htdocs/* && \
    echo "Downloading froxlor ${FROXLOR_VERSION}" && \
    curl -s https://files.froxlor.org/releases/froxlor-${FROXLOR_VERSION}.tar.gz | \
      tar -C /var/www/localhost/htdocs/ --strip-components=1 -x -z -f - && \
    echo "Checking install requirements ... " && \
    CHECK=$( HTTP_ACCEPT_LANGUAGE=en php7 /var/www/localhost/htdocs/install/install.php ) && \
    echo $CHECK | html2text -style pretty && \
    echo $CHECK | grep -v -e "Cannot install" > /dev/null 2>&1

ADD run.sh /run.sh

CMD /run.sh
