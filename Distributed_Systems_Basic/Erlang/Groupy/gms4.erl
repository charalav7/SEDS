-module(gms4).
-export([start/1, start/2]).

-define(timeout, 1000). %% timeout 
-define(arghh, 100). %% defines the risk of crashing

%% Initializing a process that is the first node in a group
start(Id) ->
	%% add random number seed to avoid all processes crashing
	%% at the same time
    Rnd = random:uniform(1000),
    Self = self(),
    spawn_link(fun() -> init(Id, Rnd, Self) end).

init(Id, Rnd, Master) ->
    random:seed(Rnd, Rnd, Rnd),
    leader(Id, Master, 1, [], [Master], []). %%INCLUDE EXTRA LIST FOR MULTICASTED MESSAGES

%% Starting a node that should join an existing group
start(Id, Grp) ->
    Rnd = random:uniform(1000),
    Self = self(),
    spawn_link(fun() -> init(Id, Rnd, Grp, Self) end).

init(Id, Rnd, Grp, Master) ->
    random:seed(Rnd, Rnd, Rnd),
    Self = self(),
    Grp ! {join, Master, Self},
    receive
		{view, N, [Leader|Slaves], Group} ->
	    	Master ! {view, Group},
	    	erlang:monitor(process, Leader),
	    	slave(Id, Master, Leader, N+1, {view, N, [Leader|Slaves], Group}, Slaves, Group)
    after ?timeout ->
	    Master ! {error, "no reply from leader"}
    end.

%% Leader process
leader(Id, Master, N, Slaves, Group, MultiList) -> %%ADDED MultiList
    receive
		{mcast, Msg} ->
	    	bcast(Id, {msg, N, Msg}, Slaves),
	    	Master ! Msg,
	    	NewMultiList = [{N,Msg}|MultiList], %%ADDED TO STORE MULTICASTED MESSAGES
	    	leader(Id, Master, N+1, Slaves, Group, NewMultiList); %%ADDED NewMultiList
		{join, Wrk, Peer} ->
	    	Slaves2 = lists:append(Slaves, [Peer]),
	    	Group2 = lists:append(Group, [Wrk]),
	    	bcast(Id, {view, N, [self()|Slaves2], Group2}, Slaves2),
	    	Master ! {view, Group2},
	    	leader(Id, Master, N+1, Slaves2, Group2, MultiList); %%ADDED MultiList
		%%ADDED NEW RECEIVE
		{reMsg, I, P} ->
			case lists:keyfind(I, 1, MultiList) of 
				{S, Message} ->
					io:format("Leader sends again messages~n"),
					P ! {resendMsg, S, Message},
					leader(Id, Master, N, Slaves, Group, MultiList);
				false ->
					io:format("Message not found in the Leader's list"),
					leader(Id, Master, N, Slaves, Group, MultiList)
			end;		
		stop ->
	    	ok;
		Error ->
	    	io:format("gms ~w: leader, strange message ~w~n", [Id, Error])
    end.

%% Slave process
%% 'N' is the sequence number of the next message
%% 'Last' is a copy of the last message received from the leader
slave(Id, Master, Leader, N, Last, Slaves, Group) ->
    receive
		{mcast, Msg} ->
	    	Leader ! {mcast, Msg},
	    	slave(Id, Master, Leader, N, Last, Slaves, Group);
		{join, Wrk, Peer} ->
	    	Leader ! {join, Wrk, Peer},
	    	slave(Id, Master, Leader, N, Last, Slaves, Group);
		{msg, N, Msg} ->
	    	% new message format
	    	Master ! Msg,
	    	slave(Id, Master, Leader, N+1, {msg, N, Msg}, Slaves, Group);
		{msg, I, _} when I < N->    
	    	% discard messages that we have seen
	    	slave(Id, Master, Leader, N, Last, Slaves, Group);
		%%ADDED NEW RECEIVE
		{msg, I, Msg} when I > N ->
			Lx = lists:seq(N, I),
			io:format("Msg: ~w, lost by slave: ~w~n", [Lx, Id]),
			lists:map(fun(Value) -> Leader ! {reMsg, Value, self()}  end, Lx),
			Master ! Msg,
			slave(Id, Master, Leader, I+1, {msg,I,Msg}, Slaves, Group);
		{view, N, [Leader|Slaves2], Group2} ->
	    	% a view message with seqquence number
	    	Master ! {view, Group2},
	    	slave(Id, Master, Leader, N+1, {view, N, [Leader|Slaves2], Group2}, Slaves2, Group2);
		{'DOWN', _Ref, process, Leader, _Reason} ->
			%% a slave who sees leader is died will move 
	    	%% to an election state
	    	election(Id, Master, N, Last, Slaves, Group);
	    %%ADDED NEW RECEIVE
	    {resendMsg, S, _} ->
	    	io:format("Lost message: ~w, received again by slave: ~w~n",[S,Id]),
			slave(Id, Master, Leader, N, Last, Slaves, Group);	
		stop ->
	    	ok;
		Error ->
	    	io:format("gms ~w: slave, strange message ~w~n", [Id, Error])
    end.

bcast(Id, Last, Rest) ->
    lists:foreach(fun(Node) -> Node ! Last, crash(Id) end, Rest).

crash(Id) ->
	%% a process will crash in average once in 100 attempts
    case random:uniform(?arghh) of
		?arghh ->
	   		io:format("leader ~w: crash~n", [Id]),
	    	exit(no_luck);
		_ ->
	    	ok
    end.

%% add an election process for choosing next leader
election(Id, Master, N, Last, Slaves, [_|Group]) ->
    Self = self(),
    case Slaves of
		[Self|Rest] ->
			%% if itself being the first node and thus become 
	    	%% the leader of group
	    	bcast(Id, Last, Rest),
	   		bcast(Id, {view, N, Slaves, Group}, Rest),
	    	Master ! {view, Group},
	    	leader(Id, Master, N+1, Rest, Group, []); %%ADDED [] FOR THE CALL OF leader
		[Leader|Rest] ->
			%% elect the first node in the Slaves and it becomes leader
	    	erlang:monitor(process, Leader),
	    	slave(Id, Master, Leader, N, Last, Rest, Group)
    end.