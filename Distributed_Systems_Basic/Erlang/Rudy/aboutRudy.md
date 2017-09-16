# Rudy: A small web server

A small web server for handling requests. 

Details for execution in command prompts on the same Windows computer with WiFi network:

1. Open a command prompt and type: 

    erl -name first@yourIPnetworkAdress -setcookie secret
	
2. Type the following orders:

    c(http).
	
    c(rudy).
	
    rudy:start(8080).
	
3. Open a different commant prompt window on the same computer and type:

    erl -name second@yourIPnetworkAdress -setcookie secret
    
4. A connection is now established.   

5. Then type at this command prompt: 

    c(test).
    
    test:bench("localhost", 8080).
    
6. Now you can check how many micro seconds it took the server to handle 100 requests.

Tip #1: Be carefull to change yourIPnetworkAdress in the above corresponding orders. 
        You can find your IP by typing ipconfig in a different command prompt.
     
Tip #2: Have in mind to have Erlang in the PATH.

Tip #3: Type in the first command prompt window to stop the server: 
        rudy:start(8080).
