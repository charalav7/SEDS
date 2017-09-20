-module(hist).
-author("chara").
-export([new/1, update/3]).

new(Name) -> [{Name, inf}]. %inf makes message look old

update(Node, N, History) ->
  case lists:keyfind(Node, 1, History) of
    {_, Counter} ->
      case N of
        N when N > Counter -> {new, [{Node, N} | lists:keydelete(Node, 1, History)]};
        _ -> old
      end;
    false -> {new, [{Node, N} | History]}
  end.


