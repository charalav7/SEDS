-module(dijkstra).
-author("chara").
-export([table/2, route/2]).

entry(Node, Sorted) ->
  case lists:keyfind(Node, 1, Sorted) of
    {_,Length,_} -> Length;
    false -> 0
  end.

replace(Node, N, Gateway, Sorted) ->
  Sorted2 = lists:keyreplace(Node, 1, Sorted, {Node, N, Gateway}),
  lists:keysort(2, Sorted2).

update(Node, N, Gateway, Sorted) ->
  L = entry(Node, Sorted),
  case L of
    L when L > N ->
      replace(Node, N, Gateway, Sorted);
    _ -> Sorted
  end.

iterate([], Map, Table)->
  Table;

iterate([{_,inf,_} | _], Map, Table) ->
  Table;

iterate([{Head, N, Gateway}|Tail], Map, Table)->
  Links = map:reachable(Head, Map),
  SortedList = lists:foldl(fun(Node, NewSortedList) -> update(Node, N+1, Gateway, NewSortedList) end, Tail, Links),
  NewTable = [{Head, Gateway} | Table],
  iterate(SortedList, Map, NewTable).

table(Gateways, Map) ->
  AllNodes = map:all_nodes(Map),
  SortedList = lists:keysort(2, lists:map(fun(Node) ->
    case lists:member(Node,Gateways) of
      true ->
        {Node, 0, Node};
      false ->
        {Node, inf, unknown}
    end
                                          end, AllNodes)),
  iterate(SortedList, Map, []).

route(Node,Table) ->
  case lists:keyfind(Node, 1, Table) of
    {_, Gateway} ->
      {ok,Gateway};
    false ->
      notfound
  end.