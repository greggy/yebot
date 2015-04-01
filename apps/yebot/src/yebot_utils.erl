%%%-------------------------------------------------------------------
%%% @author greg <greg@localhost>
%%% @copyright (C) 2015, greg
%%% @doc
%%%
%%% @end
%%% Created : 27 Mar 2015 by greg <greg@localhost>
%%%-------------------------------------------------------------------
-module(yebot_utils).

%% API
-export([
	 md5_hex/1,
	 random_number/0
]).

-define(BYTES, 10).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
md5_hex(S) ->
    Md5_bin = erlang:md5(S),
    Md5_list = binary_to_list(Md5_bin),
    list_to_binary(lists:flatten(list_to_hex(Md5_list))).


random_number() ->
    NList = lists:seq(0, 9),
    list_to_binary(lists:concat([begin 
				     Indx = random:uniform(10),
				     X = lists:nth(Indx, NList),
				     integer_to_list(X)
				 end || _ <- lists:seq(1, ?BYTES)])).


%%%===================================================================
%%% Internal functions
%%%===================================================================

list_to_hex(L) ->
    lists:map(fun(X) -> int_to_hex(X) end, L).

int_to_hex(N) when N < 256 ->
    [hex(N div 16), hex(N rem 16)].

hex(N) when N < 10 ->
    $0+N;
hex(N) when N >= 10, N < 16 ->
    $a + (N-10).



