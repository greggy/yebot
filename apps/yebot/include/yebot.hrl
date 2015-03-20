%%% @author greg <greg@localhost>
%%% @copyright (C) 2015, greg
%%% @doc
%%%
%%% @end
%%% Created : 23 Feb 2015 by greg <greg@localhost>


-record(config, {
	  socket :: gen_tcp:socket(),
	  name :: binary(),
	  server :: binary(),
	  pass :: binary(),
	  muc :: binary(),
	  rooms :: list(binary())
}).



