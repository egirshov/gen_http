-module(http_client).

-compile(export_all).
-define(D(X), io:format("~p ~p~n", [?LINE,X])).

-compile({no_auto_import,[now/0]}).

start() ->
  Pid = spawn(fun () -> make_request("127.0.0.1", 80) end),
  Pid ! stop.

make_request(Host, Port) ->
  ?D("new request"),
	{ok, Socket} = gen_http:connect(Host, Port),
  gen_http:setopts(Socket, [{chunk_size, 1024}]),
	ok = gen_http:send(Socket, ["GET / HTTP/1.1\r\nHost: " ++ Host ++ 
      "\r\nContent-Length: 0\r\n\r\n"]),
	gen_http:active_once(Socket),
  receive
		{http, Socket, Status, _Keepalive, _Version, Headers} ->
			?D({response, Status})
  end,
  {ContentLength, _} = string:to_integer(binary_to_list(
      proplists:get_value('Content-Length', Headers))),
  Data = receive_body(Socket, ContentLength, ""),
  ?D({data, Data}),
  receive
    stop -> 
      ?D("stopping"),
      ok
    after 1000 -> 
      make_request(Host, Port)
  end.

receive_body(Socket, ContentLength, Body) ->
	receive 
    {http, Socket, eof} ->
      Body;
	  {http, Socket, Data} ->
      receive_body(Socket, ContentLength, 
          Body ++ binary:bin_to_list(Data, {0, ContentLength - 1}))
  end.
