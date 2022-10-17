#!/usr/bin/env bash
set -o pipefail

ACCEPTABLE_LAG=59

#
# Status ok, return 'HTTP 200'
#
http_200 () {
    echo -e "HTTP/1.1 200 OK\r\n"
    echo -e "Content-Type: Content-Type: text/plain\r\n"
    echo -e "\r\n"
    echo -e "$1"
    echo -e "\r\n"
}

#
# Status not ok, return 'HTTP 503'
#
http_503 () {
    echo -e "HTTP/1.1 503 Service Unavailable\r\n"
    echo -e "Content-Type: Content-Type: text/plain\r\n"
    echo -e "\r\n"
    echo -e "$1"
    echo -e "\r\n"
}

#
# Server not found, maybe MySQL is down, return 'HTTP 404'
#
http_404 () {
    echo -e "HTTP/1.1 404 Not Found\r\n"
    echo -e "Content-Type: Content-Type: text/plain\r\n"
    echo -e "\r\n"
    echo -e "$1"
    echo -e "\r\n"
}

slave_lag=$(mysql -S /var/run/mysqld/mysqld.sock -e "SHOW SLAVE STATUS\G" -ss 2>/dev/null \
    | grep 'Seconds_Behind_Master' \
    | awk '{ print $2 }')
exit_code=$?

if [[ "$exit_code" != "0" ]]
then
    http_404 "MySQL error"
fi

if [[ -n "$slave_lag" && $slave_lag -gt $ACCEPTABLE_LAG ]]
then
    http_503 "Replica lagging"
fi

if [[ -n "$slave_lag" && $slave_lag -le $ACCEPTABLE_LAG ]]
then
    http_200 "Replica OK"
fi
