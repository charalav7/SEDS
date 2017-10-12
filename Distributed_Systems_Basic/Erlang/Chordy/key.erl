-module (key).
-export ([generate/0, between/3]).

generate() ->	
	rand:uniform(1000000000). % generate random numbers (30-bits)

between(Key, From, To) when From==To ->
	true;
between(Key, From, To) when From < To->
	if
		(From<Key) and (Key=< To) ->
			true;
		true ->
			false
		end;
between(Key, From, To) when From > To ->
	case between(Key, To, From) of
		true ->
			false;
		false ->
			true
	end.

