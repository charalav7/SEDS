-module(logger).
-author("chara").
-export([start/1, stop/1]).

start(Nodes) ->
  spawn_link(fun() ->init(Nodes) end).

stop(Logger) ->
  Logger ! stop.

init(Nodes) ->
  Clock = time:clock(Nodes), % Initialize: Clock = [{john, 0}, {paul, 0}, {ringo, 0}, {george, 0}]
  loop(Clock, []). % Initialize: Queue = [], afterwards: Queue = [{From, Time, Msg}, ...]

loop(Clock, Queue) ->
  receive
    {log, From, Time, Msg} ->
      NewClock = time:update(From, Time, Clock), % NewClock = [{john, 1}, ... ]
      NewQueue = lists:keysort(2, Queue ++ [{From, Time, Msg}]), % Add new entry and sort at the same time the Queue,  NewQueue = [{john, 1, Msg}, ...]
      {SafeToLog, RestQueue} = lists:splitwith(fun({_, T, _}) -> time:safe(T, Clock) end, NewQueue), % Split to two lists, the safe to print and the remaining
      lists:foreach(fun(SafeEntry) -> log(SafeEntry) end, SafeToLog),
      %io:format("RestQueue length: ~p~n", [length(RestQueue)]), % Just to test the length of the non safe list, with entries that wait to be printed
      loop(NewClock,RestQueue); % Loop with the non safe list, avoiding the safe entries that have already been printed
    stop ->
      io:format("Remained at the Queue: ~p entries~n", [length(Queue)]), % When the Log is stopped there are some entries in the sorted Queue that have not been printed
      lists:foreach(fun(SafeEntry) -> log(SafeEntry) end, Queue), % Safe to print the remaining Queue as the procedure is over
      ok
  end.

log({From, Time, Msg}) ->
  io:format("log: ~w ~w ~p~n", [Time, From, Msg]).