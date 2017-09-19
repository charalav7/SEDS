-module(map).
-author("chara").
-export([new/0, update/3, reachable/2, all_nodes/1]).

new()-> [].

update(Node, Links, Map)->
  case lists:keyfind(Node, 1, Map) of
    {_, _} ->
      lists:keyreplace(Node, 1, Map, {Node, Links});
    false ->
      [{Node, Links}| Map]
  end.

reachable(Node, Map)->
  case lists:keyfind(Node, 1, Map) of
    {_, L} ->
      L;
    false ->
      []
  end.

all_nodes(Map) ->
  Acc0 = [],
  lists:foldl(fun(Value, Acc) -> parseValue(Value, Acc) end, Acc0, Map).
  parseValue({Node, Links}, Acc) ->
    lists:foldl(fun(Value, Acc2) ->
      case lists:member(Value, Acc2) of
        false ->
          [Value|Acc2];
        true ->
          Acc2
      end
                end, Acc, [Node|Links]).