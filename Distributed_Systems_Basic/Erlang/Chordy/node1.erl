-module (node1).
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
    node(Id, Predecessor, Successor).

% when we're alone, we are our own successor
connect(Id, nil) ->
    {ok, {Id, self()}};

% trying to connect to an existing ring
% send key message to the node (peer) and wait for reply
connect(_, Peer) ->
    Qref = make_ref(), % returns unique ref among connected nodes
    Peer ! {key, Qref, self()},
    receive
		{Qref, Skey} ->
	    	{ok, {Skey, Peer}}
    	after ?Timeout -> %return error after e.g 10 sec
	    	io:format("Time out: no response~n", [])
    end.        

node(Id, Predecessor, Successor) ->
    receive
		% a peer needs to know our key
		{key, Qref, Peer} ->
	    	Peer ! {Qref, Id},
	    	node(Id, Predecessor, Successor);

		% a new node informs us of its existence
		{notify, New} ->
	    	Pred = notify(New, Id, Predecessor),
	    	node(Id, Pred, Successor);

		% a predecessor needs to know our predecessor
		{request, Peer} ->
	    	request(Peer, Predecessor),
	    	node(Id, Predecessor, Successor);

		% our successor informs us about its predecessor
		{status, Pred} ->
	    	Succ = stabilize(Pred, Id, Successor), % the ring is stablilized
	    	node(Id, Predecessor, Succ);

	    % call stabilize/1 function to simply send a request msg to its successor	
	    stabilize ->
	    	stabilize(Successor),
	    	node(Id, Predecessor, Successor);

	    % to check if ring is actually connected
		probe ->
	    	create_probe(Id, Successor),
	    	node(Id, Predecessor, Successor);

		{probe, Id, Nodes, T} ->
	    	remove_probe(T, Nodes),
	    	node(Id, Predecessor, Successor);
	
		% if this is not our probe we simply forward it to our successor
		{probe, Ref, Nodes, T} ->
	    	forward_probe(Ref, T, Nodes, Id, Successor),
	    	node(Id, Predecessor, Successor);

	    % handler to print out some state info
	    state ->
			io:format("Id: ~w, Predecessor: ~w, Successor: ~w~n", [Id, Predecessor, Successor]),
			node(Id, Predecessor, Successor);

	    % for receiving to stop	
	    stop -> 
	    	io:format("Stopped~n"),
	    	ok;

	    % for anything else received
		_ ->
	    	io:format('Strange message received ~n'),
	    	node(Id, Predecessor, Successor)			
	end. 


% just send a request message to its successor
stabilize({_, Spid}) ->
    Spid ! {request, self()}.

% 'Pred', is our successor's current predecessor
% 'Id', is Id of the current node
% 'Successor', is successor of the current node

% to select correclty every time the successor 
stabilize(Pred, Id, Successor) ->
    {Skey, Spid} = Successor,
    case Pred of
		nil -> % notify about our existence
	    	Spid ! {notify, {Id, self()}}, 
	    	Successor;
		{Id, _} -> % pointing back to us
	    	Successor;
		{Skey, _} -> % pointing to itself
	    	Spid ! {notify, {Id, self()}},
	    	Successor;
		{Xkey, Xpid} -> % pointing to another node
	    	case key:between(Xkey, Id, Skey) of
				true -> 
					% if XKey is between us and our successor then 
					% we should adopt this node as our successor and 
					% run stabalization again
		    		stabilize(Pred,Id,{Xkey,Xpid});
				false ->
		    		% if we are in between the nodes we inform our successor of our existence
		    		Spid ! {notify, {Id, self()}},
		    		Successor
	    	end
    end.	   	

% set up a timer and send the request message
% to the successor after a predefined interval (1000 ms)
% so that new nodes are quickly linked into the ring. 
schedule_stabilize() ->
    timer:send_interval(?Stabilize, self(), stabilize).  

% inform the peer that sent the request about predecessor
request(Peer, Predecessor) ->
    case Predecessor of
		nil ->
	    	Peer ! {status, nil};
		{Pkey, Ppid} ->
	    	Peer ! {status, {Pkey, Ppid}}
    end.  

% check if this node could be our proper predecessor
notify({Nkey, Npid}, Id, Predecessor) ->
    case Predecessor of	
		nil -> % no predecessor
	    	{Nkey, Npid};
		{Pkey, Ppid} ->
	    	case key:between(Nkey, Pkey, Id) of
	    		% check if the new node could actually be our predecessor or not
				true ->
					Npid ! {status,{Nkey,Npid}},		    
		   			{Nkey, Npid};
				false ->
					Npid ! {status,{Pkey, Ppid}},
		    		Predecessor
	    	end
    end.

% timestamp is set when creating the probe
create_probe(Id,{_,Spid}) ->
    io:format("Creating probe with Id: ~w~n",[Id]),
	Spid ! {probe, Id, [], erlang:system_time(micro_seconds)}.

% report the time it took to pass it around the ring.
remove_probe(T, Nodes) ->
    Duration = (erlang:system_time(micro_seconds) - T),
	io:format("Probe's duration time around the ring: ~w microsec, while it hopped through ~w~n", [Duration, Nodes]).

% if it is not our probe we simply forward it to our successor
% but add our own process identifier to the list of nodes
forward_probe(Ref, T, Nodes, Id, {_,Spid}) ->
	io:format("Forwarding probe at Id: ~w~n",[Id]),
    Spid ! {probe,Ref,Nodes ++ [Id],T}.            