%%%-------------------------------------------------------------------
%%% @author greg <greg@localhost>
%%% @copyright (C) 2015, greg
%%% @doc
%%%
%%% @end
%%% Created : 22 Feb 2015 by greg <greg@localhost>
%%%-------------------------------------------------------------------
-module(yebot_worker_sup).

-behaviour(supervisor).

-include("yebot.hrl").


%% API
-export([start_link/2, start_worker/4]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% Helper macro for declaring children of supervisor
-define(CHILD(M, Type, Args), {M, {M, start_link, Args}, permanent, 5000, Type, [M]}).


%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Name, Bot) ->
    supervisor:start_link({local, Name}, ?SERVER, [Bot]).


start_worker(Socket, Name, Server, Room) ->
    SupRef = binary_to_atom(Server, latin1),
    WorkerName = <<Room/binary, ":", Server/binary>>,
    WorkerSpec = {WorkerName, {yebot_worker, start_link, [Socket, Name, Server, Room]},
		  permanent, 5000, worker, [yebot_worker]},
    case supervisor:start_child(SupRef, WorkerSpec) of
	{ok, Pid} -> Pid;
	{ok, Pid, _Info} -> Pid
    end.


%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init([Bot]) ->
    DispWorker = ?CHILD(yebot_disp, worker, [Bot]),

    {ok, { {one_for_all, 5, 10}, [DispWorker]} }.

%%%===================================================================
%%% Internal functions
%%%===================================================================

