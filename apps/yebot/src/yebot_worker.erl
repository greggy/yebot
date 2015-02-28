%%%-------------------------------------------------------------------
%%% @author greg
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. фев 2015 16:34
%%%-------------------------------------------------------------------
-module(yebot_worker).
-author("greg").

-behaviour(gen_server).

-include("yebot.hrl").
-include_lib("exml/include/exml.hrl").
-include_lib("exml/include/exml_stream.hrl").

%% API
-export([start_link/4]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
	  server :: gen_tcp:socket(),
	  room :: binary(),
	  name :: binary(),
	  socket :: atom()
}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(gen_tcp:socket(), binary(), binary(), binary()) ->
	     {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Socket, Name, Server, Room) ->
    gen_server:start_link(?MODULE, [Socket, Name, Server, Room], []).

%%%===================================================================
%% gen_server callbacks
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
init([Socket, Name, Server, Room]) ->
    lager:info("Start worker ~p room ~p!!", [Server, Room]),
    {ok, #state{name = Name,
		server = Server, 
		room = Room,
		socket = Socket}}.

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
handle_info({get_data, Data}, State) ->
    parse_xml(Data, State),
    {noreply, State};

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
terminate(Reason, _State) ->
    lager:info("WORKER STOP with reason ~p!!!", [Reason]),
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

parse_xml([#xmlel{name= <<"iq">>, attrs=[{<<"type">>, <<"result">>}|_]}],
	  #state{name=Name, server=Server, room=Room, socket=Socket}) ->
    lager:info("New sessions started!!"),
    XmlPacket = xml_packet(presence, {Name, Server, Room}),
    gen_tcp:send(Socket, XmlPacket);

parse_xml([#xmlel{name= <<"message">>}=Data], #state{name=Name, socket=Socket}=State) ->
    Body = exml_query:subelement(Data, <<"body">>),
    CData = exml_query:cdata(Body),
    case binary:match(CData, Name) of
	nomatch -> parse_xml(Data, State);
	_ ->
	    From = exml_query:attr(Data, <<"from">>),
	    XmlPacket = xml_packet(message, {<<"pong">>, From}),
	    gen_tcp:send(Socket, XmlPacket)
    end;

parse_xml(Data, _) ->
    lager:info("RECV XML: ~n~p~n", [Data]).


xml_packet(presence, <<"unavailable">> =Status) ->
    <<"<presence xmlns='jabber:client' type='", Status/binary, "' />">>;

xml_packet(presence, {Name, Server, Room}) ->
    <<"<presence from='", Name/binary, "@", Server/binary, "/erlang' id='97460003' to='", Room/binary, "@conference.", Server/binary, "/", Name/binary, "'><x xmlns='http://jabber.org/protocol/muc' /></presence>">>;

xml_packet(close, stream) ->
    <<"</stream:stream>">>;

xml_packet(message, {Msg, To}) ->
    <<"<message to='.conf@conference.jabber.ru' from='yebot@jabber.ru/erlang' type='groupchat'><body>", Msg/binary,"</body></message>">>.
