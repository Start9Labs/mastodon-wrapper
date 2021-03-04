#!/bin/bash

set -ea

_term() { 
  echo "Caught SIGTERM signal!" 
  kill -TERM "$postgres_child" 2>/dev/null
  kill -TERM "$redis_child" 2>/dev/null
  kill -TERM "$nginx_child" 2>/dev/null
  kill -TERM "$streaming_child" 2>/dev/null
  kill -TERM "$sidekiq_child" 2>/dev/null
  kill -TERM "$puma_child" 2>/dev/null
  kill -TERM "$privoxy_child" 2> /dev/null
}

HOST_IP=$(ip -4 route list match 0/0 | awk '{print $3}')
echo "$HOST_IP   tor" >> /etc/hosts

mkdir -p /root/persistence/system
test -d /mastodon/public/system || ln -s /root/persistence/system /mastodon/public/system
mkdir -p /root/persistence/log
if [ -d /mastodon/log ]; then
    rm -r /mastodon/log
fi
ln -s /root/persistence/log /mastodon/log

LOCAL_DOMAIN="$TOR_ADDRESS"
ALTERNATE_DOMAINS="$TOR_ADDRESS,$(echo "$TOR_ADDRESS" | sed -r 's/(.+)\.onion/\1.local/g')"
STREAMING_API_BASE_URL="ws://$TOR_ADDRESS"
DB_HOST=localhost
DB_USER=postgres
DB_NAME=postgres
DB_PORT=5432
REDIS_URL="redis://localhost:6379"
http_proxy="http://localhost:8118"
ALLOW_ACCESS_TO_HIDDEN_SERVICE=true
if yq e -e ".single-user-mode" /root/persistence/start9/config.yaml > /dev/null; then
  SINGLE_USER_MODE=true
fi
if [ "$(yq e ".advanced.smtp.enabled" /root/persistence/start9/config.yaml)" = "true" ]; then
  SMTP_SERVER="$(yq e ".advanced.smtp.address" /root/persistence/start9/config.yaml)"
  SMTP_PORT="$(yq e ".advanced.smtp.port" /root/persistence/start9/config.yaml)"
  SMTP_FROM_ADDRESS="$(yq e ".advanced.smtp.from-address" /root/persistence/start9/config.yaml)"
  if yq e -e ".advanced.smtp.domain" /root/persistence/start9/config.yaml > /dev/null; then
    SMTP_DOMAIN="$(yq e ".advanced.smtp.domain" /root/persistence/start9/config.yaml)"
  fi
  if [ "$(yq e ".advanced.smtp.authentication.type" /root/persistence/start9/config.yaml)" != "none" ]; then
    SMTP_AUTH_METHOD="$(yq e ".advanced.smtp.authentication.type" /root/persistence/start9/config.yaml)"
  fi
  if yq e -e ".advanced.smtp.authentication.username" /root/persistence/start9/config.yaml > /dev/null; then
    SMTP_LOGIN="$(yq e ".advanced.smtp.authentication.username" /root/persistence/start9/config.yaml)"
  fi
  if yq e -e ".advanced.smtp.authentication.password" /root/persistence/start9/config.yaml > /dev/null; then
    SMTP_PASSWORD="$(yq e ".advanced.smtp.authentication.password" /root/persistence/start9/config.yaml)"
  fi
  if yq e -e ".advanced.smtp.enable-starttls-auto" /root/persistence/start9/config.yaml > /dev/null; then
    SMTP_ENABLE_STARTTLS_AUTO=true
  fi
  if [ "$(yq e ".advanced.smtp.ssl.enable" /root/persistence/start9/config.yaml)" = "true" ]; then
    SMTP_SSL=true
    SMTP_TLS=true
    SMTP_OPENSSL_VERIFY_MODE="$(yq e ".advanced.smtp.ssl.openssl-verify-mode" /root/persistence/start9/config.yaml)"
  fi
else
  SMTP_DISABLE=true
fi
cd /mastodon
test -f /root/persistence/secret_key_base.txt || bundle exec rake secret > /root/persistence/secret_key_base.txt
SECRET_KEY_BASE=$(cat /root/persistence/secret_key_base.txt)
test -f /root/persistence/otp_secret.txt || bundle exec rake secret > /root/persistence/otp_secret.txt
OTP_SECRET=$(cat /root/persistence/otp_secret.txt)
test -f /root/persistence/vapid.env || bundle exec rake mastodon:webpush:generate_vapid_key > /root/persistence/vapid.env
source /root/persistence/vapid.env

if [ "$#" -ne 0 ]; then
  exec $@
fi

chmod 777 /root
chmod 777 /root/persistence
mkdir -p /root/persistence/pgdata
chown -R postgres:postgres /root/persistence/pgdata
test -f /root/persistence/pgdata/PG_VERSION || sudo -u postgres initdb -D /root/persistence/pgdata
sudo -u postgres postgres -D /root/persistence/pgdata &
postgres_child=$!
mkdir -p /root/persistence/redis-data
echo "dir /root/persistence/redis-data" | redis-server - &
redis_child=$!

bundle exec rake db:migrate

nginx -g "daemon off;" &
nginx_child=$!
privoxy --no-daemon /etc/privoxy/config &
privoxy_child=$!
node ./streaming &
streaming_child=$!
bundle exec sidekiq &
sidekiq_child=$!
exec bundle exec puma -C config/puma.rb &
puma_child=$!

echo "All services started..."

trap _term SIGTERM

wait -n $postgres_child $redis_child $nginx_child $privoxy_child $streaming_child $sidekiq_child $puma_child