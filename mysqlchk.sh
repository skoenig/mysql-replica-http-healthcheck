#!/usr/bin/env bash
set -o pipefail

ACCEPTABLE_LAG=59

http_response () {
    HTTP_CODE=$1
    MESSAGE=${2:-Message Undefined}
    length=${#MESSAGE}
    if [[ "$HTTP_CODE" -eq 503 ]]
    then
      echo -en "HTTP/1.1 503 Service Unavailable\r\n"
    elif [[ "$HTTP_CODE" -eq 404 ]]
    then
      echo -en "HTTP/1.1 404 Not Found\r\n"
    elif [[ "$HTTP_CODE" -eq 200 ]]
    then
      echo -en "HTTP/1.1 200 OK\r\n"
    else
      echo -en "HTTP/1.1 ${HTTP_CODE} UNKNOWN\r\n"
    fi
    echo -en "Content-Type: Content-Type: text/plain\r\n"
    echo -en "Content-Length: ${length}\r\n"
    echo -en "\r\n"
    echo -en "$MESSAGE"
}

slave_lag=$(mysql -S /var/run/mysqld/mysqld.sock -e "SHOW SLAVE STATUS\G" -ss 2>/dev/null \
    | grep 'Seconds_Behind_Master' \
    | awk '{ print $2 }')
exit_code=$?

# Server not found, maybe MySQL is down, return 'HTTP 404'
if [[ "$exit_code" != "0" ]]
then
    http_response 404 "MySQL error"
fi

# Status not ok, return 'HTTP 503'
if [[ -n "$slave_lag" && $slave_lag -gt $ACCEPTABLE_LAG ]]
then
    http_response 503 "Replica lagging"
fi

# Status ok, return 'HTTP 200'
if [[ -n "$slave_lag" && $slave_lag -le $ACCEPTABLE_LAG ]]
then
    http_response 200 "Replica OK"
fi
