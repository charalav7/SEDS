-module(time).
-author("chara").
-export([zero/0, inc/2, merge/2, leq/2, clock/1, update/3, safe/2]).

zero() ->
  0.

inc(Name, T) ->
  T + 1.

merge(Ti, Tj) ->
  erlang:max(Ti, Tj).

leq(Ti, Tj) ->
  if (Ti =< Tj) ->
    true;
  true ->
      false
  end.

clock(Nodes) ->
  lists:map(fun(Node) -> {Node, 0} end, Nodes).

update(Node, Time, Clock) ->
  case lists:keyfind(Node, 1, Clock) of
    {_, _} ->
      lists:keyreplace(Node, 1, Clock, {Node, Time});
    false ->
      Clock
  end.

safe(Time, Clock) ->
  MinTime = lists:foldl(fun({_Node, Count}, Acc) -> erlang:min(Count, Acc) end, inf, Clock),
  leq(Time, MinTime).