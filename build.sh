set -vx
rm *.beam
erlc -I /usr/lib/ejabberd/include -pz /usr/lib/ejabberd/ebin -I ../eredis/include -pz ../eredis/ebin mod_redis_message_queue.erl
cp *.beam /usr/lib/ejabberd/ebin
