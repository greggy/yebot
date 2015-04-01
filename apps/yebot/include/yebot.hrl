%%% @author greg <greg@localhost>
%%% @copyright (C) 2015, greg
%%% @doc
%%%
%%% @end
%%% Created : 23 Feb 2015 by greg <greg@localhost>


-record(config, {
	  name :: binary(),
	  server :: binary(),
	  pass :: binary(),
	  muc :: binary(),
	  mechanism :: binary(),
	  rooms :: list(binary())
}).



