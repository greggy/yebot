%%%-------------------------------------------------------------------
%%% @author greg
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. фев 2015 16:34
%%%-------------------------------------------------------------------
-module(yebot_config).
-author("greg").

-behaviour(gen_server).

-include("yebot.hrl").
-include_lib("exml/include/exml.hrl").
-include_lib("exml/include/exml_stream.hrl").

%% API
-export([start_link/0, parse_config/1, get_servers/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-type option() :: {string(), binary() | list(binary())}.
-type bot_config() :: {binary(), list(option())}.

-record(state, {
	  servers :: list({atom(), pid()})
	  %% rooms=[] :: list(binary())
}).

%%%===================================================================
%%% API
%%%===================================================================

get_servers() ->
    gen_server:call(?SERVER, get_servers).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term()} | ignore).
init([]) ->
    {ok, Data0} = application:get_env(yebot, bots),
    Data1 = parse_config(Data0),
    lager:info("Config ~p", [Data1]),
    timer:send_after(1000, self(), {start, Data1}),
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
                  State :: #state{}) ->
                     {reply, Reply :: term(), NewState :: #state{}} |
                     {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
                     {noreply, NewState :: #state{}} |
                     {noreply, NewState :: #state{}, timeout() | hibernate} |
                     {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
                     {stop, Reason :: term(), NewState :: #state{}}).

handle_call(get_servers, _From, #state{servers=Servers}=State) ->
    {reply, {ok, Servers}, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
    {noreply, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_info({start, Bots}, State) ->
    lager:info("Start bots ~p!!!", [Bots]),
    BotsSup =
	[begin
	     Name = binary_to_atom(Bot#config.server, latin1),
	     {ok, Pid} = yebot_worker_sup:start_link(Name, Bot),
	     {Name, Pid}
	 end || Bot <- Bots ],
    {noreply, State#state{servers = BotsSup}};

handle_info(_Info, State) ->
    lager:info("Default handler ~p", [_Info]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
                State :: #state{}) ->
                   term()).
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
                  Extra :: term()) ->
                     {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec parse_config(list(bot_config())) -> list(#config{}).
parse_config(Data) ->
    parse_config(Data, []).


parse_config([{Name, Opts}|TData], Acc) ->
    Config = #config{
		name = Name,
		server = get_option("server", Opts, <<>>),
		muc = get_option("muc", Opts, <<>>),
		pass = get_option("pass", Opts, <<>>),
		mechanism = get_option("mechanism", Opts, <<"PLAIN">>),
		rooms = get_option("rooms", Opts, [])
	       },
    parse_config(TData, [Config|Acc]);

parse_config([], Acc) -> Acc.


get_option(Name, Opts, Default) ->
    proplists:get_value(Name, Opts, Default).

