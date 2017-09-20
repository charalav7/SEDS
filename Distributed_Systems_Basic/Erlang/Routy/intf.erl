-module(intf).
-author("chara").
-export([new/0, add/4, remove/2, lookup/2, ref/2, name/2, list/1, broadcast/2]).

new() -> [].

add(Name, Ref, Pid, Intf) ->
  [{Name,Ref,Pid}|Intf].

remove(Name, Intf) ->
  lists:keydelete(Name, 1, Intf).

lookup(Name, Intf) ->
  case lists:keyfind(Name, 1, Intf) of
    {_, _, _Pid} -> {ok, _Pid};
    false -> notfound
  end.

ref(Name, Intf) ->
  case lists:keyfind(Name, 1, Intf) of
    {_, _Ref, _} -> {ok, _Ref};
    false -> notfound
  end.

name(Ref, Intf) ->
  case lists:keyfind(Ref, 2, Intf) of
    {_Name, _, _} -> {ok, _Name};
    false -> notfound
  end.

list(Intf) -> lists:map(fun({Name,_,_}) -> Name end, Intf).

broadcast(Message, Intf) -> lists:map(fun({_,_,Pid}) -> Pid ! Message end, Intf).