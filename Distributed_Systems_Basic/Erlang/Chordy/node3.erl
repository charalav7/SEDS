-module (node2).
-export ([start/1, start/2]).

-define(Stabilize, 500).
-define(Timeout, 10000).

% when first node, call start/2 with nil as the predecessor
start(Id) ->
    start(Id, nil).

start(Id, Peer) ->
    timer:start(),
    spawn(fun() -> init(Id, Peer) end).

init(Id, Peer) ->
    Predecessor = nil,
    {ok, Successor} = connect(Id, Peer),
    schedule_stabilize(),
    node(Id, Predecessor, Successor, storage:create(), nil). %%ADDED nil

% when we're alone, we are our own successor
connect(Id, nil) ->
    {ok, {Id, nil, self()}}; %%ADDED nil

% trying to connect to an existing ring
% send key message to the node (peer) and wait for reply
connect(_, Peer) ->
    Qref = make_ref(), % returns unique ref among connected nodes
    Peer ! {key, Qref, self()},
    receive
		{Qref, Skey} ->
			Ref = monitor(Peer), %%ADDED
	    	{ok, {Skey, Ref, Peer}}
    	after ?Timeout -> %return error after e.g 10 sec
	    	io:format("Time out: no response~n", [])
    end.        

node(Id, Predecessor, Successor, Store, Next) ->
    receive
		% a peer needs to know our key
		{key, Qref, Peer} ->
	    	Peer ! {Qref, Id},
	    	node(Id, Predecessor, Successor, Store, Next);

		% a new node informs us of its existence
		{notify, New} ->
	    	{Pred, Keep} = notify(New, Id, Predecessor, Store),
	    	node(Id, Pred, Successor, Keep, Next);

		% a predecessor needs to know our predecessor
		{request, Peer} ->
	    	request(Peer, Predecessor),
	    	node(Id, Predecessor, Successor, Store, Next);

		% our successor informs us about its predecessor
		{status, Pred, Nx} -> %ADDED
	    	{Succ, Nxt} = stabilize(Pred, Id, Successor, Nx), % the ring is stablilized
	    	node(Id, Predecessor, Succ, Store, Nxt);

	    % call stabilize/1 function to simply send a request msg to its successor	
	    stabilize ->
	    	stabilize(Successor),
	    	node(Id, Predecessor, Successor, Store, Next);

	    % to check if ring is actually connected
		probe ->
	    	create_probe(Id, Successor),
	    	node(Id, Predecessor, Successor, Store, Next);

		{probe, Id, Nodes, T} ->
	    	remove_probe(T, Nodes),
	    	node(Id, Predecessor, Successor, Store, Next);
	
		% if this is not our probe we simply forward it to our successor
		{probe, Ref, Nodes, T} ->
	    	forward_probe(Ref, T, Nodes, Id, Successor),
	    	node(Id, Predecessor, Successor, Store, Next);

	    {add, Key, Value, Qref, Client} ->
      		Added = add(Key, Value, Qref, Client, Id, Predecessor, Successor, Store),
      		node(Id, Predecessor, Successor, Added, Next);

    	{lookup, Key, Qref, Client} ->
      		lookup(Key, Qref, Client, Id, Predecessor, Successor, Store),
      		node(Id, Predecessor, Successor, Store, Next);

      	% used to delegate responsibility	
      	{handover, Elements} ->
      		Merged = storage:merge(Store, Elements),
      		node(Id, Predecessor, Successor, Merged, Next);		

      	% handler to print out some state info
	    state ->
			io:format("Id: ~w, Predecessor: ~w, Successor: ~w, Storage: ~w, Next: ~w~n", [Id, Predecessor, Successor, Store, Next]),
			node(Id, Predecessor, Successor, Store);

		%ADDED for handling failure
		{'DOWN', Ref, process, _ , _} ->
			{Pred, Succ, Nxt} = down(Ref, Predecessor, Successor, Next),
			node(Id, Pred, Succ, Store, Nxt);	

	    % for receiving to stop	
	    stop -> 
	    	io:format("Stopped~n"),
	    	ok;

	    % for anything else received
		_ ->
	    	io:format('Strange message received ~n'),
	    	node(Id, Predecessor, Successor, Store, Next)			
	end. 

% adding an element
add(Key, Value, Qref, Client, Id, {Pkey, _}, {_, Spid}, Store) ->
  case key:between(Key,Pkey,Id) of
    true -> 
      Client ! {Qref, ok},
      storage:add(Key,Value,Store);
    false ->
      Spid ! {add,Key,Value,Qref,Client},
      Store
  end.

% lookup procedure
lookup(Key, Qref, Client, Id, {Pkey, _}, {_, Spid}, Store) ->
  case key:between(Key,Pkey,Id) of
    true -> % do a simple lookup in the local store and then send the reply to the requester.
      Result = storage:lookup(Key, Store),
      Client ! {Qref, Result};
    false -> % not our responsibility we simply forward the request
      Spid ! {lookup,Key,Qref,Client}
  end. 

% just send a request message to its successor
stabilize({_, _, Spid}) ->
    Spid ! {request, self()}.

% 'Pred', is our successor's current predecessor
% 'Id', is Id of the current node
% 'Successor', is successor of the current node

% to select correclty every time the successor 
stabilize(Pred, Id, Successor, Nx) ->
    {Skey, SRef, Spid} = Successor,
    case Pred of
		nil -> % notify about our existence
	    	Spid ! {notify, {Id, self()}}, 
	    	{Successor, Nx};
		{Id, _} -> % pointing back to us
	    	{Successor, Nx};
		{Skey, _} -> % pointing to itself
	    	Spid ! {notify, {Id, self()}},
	    	{Successor, Nx};
		{Xkey, Xpid} -> % pointing to another node
	    	case key:between(Xkey, Id, Skey) of
				true -> 
					% if XKey is between us and our successor then 
					% we should adopt this node as our successor and 
					% run stabalization again
		    		Xpid ! {notify, {Id, self()}},
					drop(SRef),
					Xref = monitor(Xpid),
					self() ! stabilize,
					{{Xkey,Xref, Xpid}, Successor};
				false ->
		    		% if we are in between the nodes we inform our successor of our existence
		    		Spid ! {notify, {Id, self()}},
		    		{Successor,Nx}
	    	end
    end.	   	

% set up a timer and send the request message
% to the successor after a predefined interval (1000 ms)
% so that new nodes are quickly linked into the ring. 
schedule_stabilize() ->
    timer:send_interval(?Stabilize, self(), stabilize).  

% inform the peer that sent the request about predecessor
request(Peer, Predecessor, Next) ->
    case Predecessor of
		nil ->
	    	Peer ! {status, nil, Next};
		{Pkey, _, Ppid} ->
	    	Peer ! {status, {Pkey, Ppid}, Next}
    end.  

% check if this node could be our proper predecessor
notify({Nkey, Npid}, Id, Predecessor,Store) ->
  case Predecessor of
    nil ->
      Keep = handover(Id, Store, Nkey, Npid),
      Nref = monitor(Npid), %%ADDED
      {{Nkey, Nref, Npid},Keep};
    {Pkey, Pref, Pid} ->
      case key:between(Nkey, Pkey, Id) of
        true ->
          Keep = handover(Id, Store, Nkey, Npid),
          drop(Pref), %%ADDED
          NRef = monitor(Npid), %%ADDED
          {{Nkey, NRef, Npid},Keep};
        false ->
          {Predecessor,Store}
      end
  end.

handover(Id,Store,Nkey,Npid) ->
  {OurStore,Rest} = storage:split(Nkey,Id,Store),
  Npid ! {handover,Rest},
  OurStore.  

% timestamp is set when creating the probe
create_probe(Id,{Skey,_,Spid}) ->
    io:format("Creating probe with Id: ~w~n",[Id]),
	Spid ! {probe, Id, [], erlang:system_time(micro_seconds)}.

% report the time it took to pass it around the ring.
remove_probe(T, Nodes) ->
    Duration = (erlang:system_time(micro_seconds) - T),
	io:format("Probe's duration time around the ring: ~w microsec, while it hopped through ~w~n", [Duration, Nodes]).

% if it is not our probe we simply forward it to our successor
% but add our own process identifier to the list of nodes
forward_probe(Ref, T, Nodes, Id, {Skey,_,Spid}) ->
	io:format("Forwarding probe at Id: ~w~n",[Id]),
    Spid ! {probe,Ref,Nodes ++ [Id],T}.                    


%%ADDED
monitor(Pid) ->
	erlang:monitor(process, Pid).
drop(nil) ->
	ok;
drop(Pref) ->
	erlang:demonitor(Pref, [flush]). 


%%ADDED
down(Ref, {_, Ref, _}, Successor, Next) ->
	io:format("Predeccessor died ~n"),
	{nil, Successor, Next};
down(Ref, Predecessor, {_, Ref, _}, {Nkey,_, Npid}) ->	
	self() ! stabilize,
	Nref = monitor(Npid),
	io:format("Successor died~n"),
	{Predecessor, {Nkey, Nref, Npid}, nil}.
