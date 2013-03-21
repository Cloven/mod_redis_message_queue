-module(mod_redis_message_queue).

-behavior(gen_mod).

-include("ejabberd.hrl").
-export([start/2, stop/1, on_user_send_packet/3]).

start(Host, _Opts) ->
  ?INFO_MSG("mod_redis_message_queue starting", []),
  ejabberd_hooks:add(user_send_packet, Host, ?MODULE, on_user_send_packet, 50),
  ok.

stop(Host) ->
  ?INFO_MSG("mod_redis_message_queue stopping", []),
  ejabberd_hooks:remove(user_send_packet, Host, ?MODULE, on_user_send_packet, 50),
  ok.

on_user_send_packet(From, To, Packet) ->
  %?INFO_MSG("mod_redis_message_queue: message received", []),
  {_,FromUsername,FromUserServer,FromUserResource,_,_,_} = From,
  {_,ToUserName,ToUserServer,ToUserResource,_,_,_} = To,
  case parse_packet(FromUsername, FromUserServer, FromUserResource, ToUserName, Packet) of
    {ok, _} ->
      ok;
    {error, Reason} ->
      %?INFO_MSG(Reason, []),
      ok
  end,
  ok.

parse_packet(FromUsername, FromUserServer, FromUserResource, ToUserName, {_,_,[_,{_,"groupchat"},_,_],XmlStanza}) ->
  [_,{_,_,_,[{_,MessageBody}]},SeparatorMaybe,NickStanza,_] = XmlStanza,
  %{_,_,[_],[{_,NickName}]} = NickStanza,
  %?INFO_MSG(FromUserResource, []),
  %?INFO_MSG(binary_to_list(NickName), []),
  %?INFO_MSG(ToUserName, []),
  %?INFO_MSG(binary_to_list(MessageBody), []),
  MessageQueuePacket = FromUserResource ++ "|" ++ ToUserName ++ "|" ++ binary_to_list(MessageBody),
  ?INFO_MSG(MessageQueuePacket, []),
  {ok, Client} = get_redis(FromUserServer),
  {ok, _ } = eredis:q(Client, ["PUBLISH", "clan_chat_outgoing", MessageQueuePacket]);
parse_packet(_,_,_,_,_) ->
  {error, "wrong_type"}.


redis_host(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_host, "127.0.0.1").

redis_port(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_port, 6379).

redis_db(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_db, 0).


get_redis(Server) ->
  case whereis(eredis_driver) of
  undefined ->
    case eredis:start_link(redis_host(Server),redis_port(Server),redis_db(Server)) of
      {ok, Client} ->
        register(eredis_driver, Client),
        ?INFO_MSG("eredis driver registered: " ++ redis_host(Server), []),
        {ok, Client};
      {error, Reason} -> 
        {error, Reason}
    end;
  Pid ->
    {ok, Pid}
end.
