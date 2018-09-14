#!/bin/bash

set -e

mkdir -p /run/apache2
rm -f /run/apache2/httpd.pid

echo "Waiting for database"
DB_READY=0
for i in {1..60}; do
  if mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < /dev/null >/dev/null 2>&1; then
    DB_READY=1
    break
  else
    echo "  Database not ready yet ($i/60)"
    sleep 1
  fi
done
if [ "${DB_READY}" != "1" ]; then
  echo "No database available - exiting"
  exit 1
fi

TABLES=$( echo "show tables" | mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} )
NUM_TABLES=$( echo "${TABLES}" | wc -l )

if [ ${NUM_TABLES} -gt 1 ]; then
  echo "Existing tables found - skipping setup"
else
  rm -f /var/www/localhost/htdocs/lib/userdata.inc.php

  ARGS="installstep=1&mysql_host=${MYSQL_HOST}&mysql_database=${MYSQL_DATABASE}&mysql_unpriv_user=${MYSQL_USER}"
  ARGS="${ARGS}&mysql_unpriv_pass=${MYSQL_PASSWORD}&mysql_root_pass=${MYSQL_ROOT_PASSWORD}"
  ARGS="${ARGS}&admin_user=admin&admin_pass1=admin&admin_pass2=admin&activate_newsfeed=0"
  ARGS="${ARGS}&httpuser=apache&httpgroup=apache"
  ARGS="${ARGS}&servername=froxlor&serverip=127.0.0.1&webserver=apache24"

  SETUP_RESULT=$(
    echo "${ARGS}" |
    SCRIPT_FILENAME=/var/www/localhost/htdocs/install/install.php \
    CONTENT_LENGTH=$( echo -n "${ARGS}" | wc -c ) \
    HTTP_ACCEPT_LANGUAGE=en \
    REDIRECT_STATUS=true \
    REQUEST_METHOD=POST \
    GATEWAY_INTERFACE=CGI/1.1 \
    CONTENT_TYPE=application/x-www-form-urlencoded \
    php-cgi )

  echo $SETUP_RESULT | html2text -style pretty

  if ! echo $SETUP_RESULT | grep -e "Froxlor was installed successfully." > /dev/null; then
    echo "Froxlor setup failed"
    exit 1
  fi
fi

cat << EOF > /var/www/localhost/htdocs/lib/userdata.inc.php
<?php
// automatically generated userdata.inc.php for Froxlor
\$sql['host']='${MYSQL_HOST}';
\$sql['user']='${MYSQL_USER}';
\$sql['password']='${MYSQL_PASSWORD}';
\$sql['db']='${MYSQL_DATABASE}';
\$sql_root[0]['caption']='Default';
\$sql_root[0]['host']='${MYSQL_HOST}';
\$sql_root[0]['user']='root';
\$sql_root[0]['password']='${MYSQL_ROOT_PASSWORD}';
// enable debugging to browser in case of SQL errors
\$sql['debug'] = false;
?>
EOF

chown -R apache:apache /var/www/localhost/htdocs

httpd -DFOREGROUND

