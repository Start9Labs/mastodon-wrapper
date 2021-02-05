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
echo "$HOST_IP   tor" | tee -a /etc/hosts

mkdir -p /root/persistence/system
test -d /mastodon/public/system || ln -s /root/persistence/system /mastodon/public/system
mkdir -p /root/persistence/log
if [ -d /mastodon/log ]; then
    rm -r /mastodon/log
fi
ln -s /root/persistence/log /mastodon/log

LOCAL_DOMAIN="$TOR_ADDRESS"
WEB_DOMAIN="$TOR_ADDRESS"
STREAMING_API_BASE_URL="ws://$TOR_ADDRESS"
DB_HOST=localhost
DB_USER=postgres
DB_NAME=postgres
DB_PORT=5432
REDIS_URL="redis://localhost:6379"
http_proxy="http://localhost:8118"
ALLOW_ACCESS_TO_HIDDEN_SERVICE=true
SINGLE_USER_MODE=true
cd /mastodon
test -f /root/persistence/secret_key_base.txt || bundle exec rake secret > /root/persistence/secret_key_base.txt
SECRET_KEY_BASE=$(cat /root/persistence/secret_key_base.txt)
test -f /root/persistence/otp_secret.txt || bundle exec rake secret > /root/persistence/otp_secret.txt
OTP_SECRET=$(cat /root/persistence/otp_secret.txt)
test -f /root/persistence/vapid.env || bundle exec rake mastodon:webpush:generate_vapid_key > /root/persistence/vapid.env
source /root/persistence/vapid.env

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
echo "Managing accounts..."

USERNAME=$(yq e '.username' /root/persistence/start9/config.yaml)
EMAIL=$(yq e '.email' /root/persistence/start9/config.yaml)
PASSWORD=$(yq e '.password' /root/persistence/start9/config.yaml) ./bin/tootctl accounts create $USERNAME --email "$EMAIL" --confirmed --role admin

trap _term SIGTERM

wait -n $postgres_child $redis_child $nginx_child $privoxy_child $streaming_child $sidekiq_child $puma_child