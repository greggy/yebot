%%%-------------------------------------------------------------------
%%% @author greg
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. фев 2015 16:34
%%%-------------------------------------------------------------------
-module(yebot_disp).
-author("greg").

-behaviour(gen_server).

-include("yebot.hrl").
-include_lib("exml/include/exml.hrl").
-include_lib("exml/include/exml_stream.hrl").

%% API
-export([start_link/1, get_rooms/1, get_socket/1]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).
-define(TIMER_DELAY, 10000).
-define(TIMER_ERROR_DELAY, 20000).

-record(state, {
	  socket :: gen_tcp:socket(),
	  server :: binary(),
	  name :: binary(),
	  pass :: binary(),
	  config_rooms=[] :: list(binary()),
	  rooms=[] :: list({binary(), pid()}),
	  xml_stream=undefined,
	  id :: binary,
	  tref=undefined :: timer:tref()
}).

%%%===================================================================
%%% API
%%%===================================================================

-spec get_rooms(Disp :: atom()) -> list() | list(binary()).
get_rooms(Disp) ->
    gen_server:call(Disp, get_rooms).


get_socket(Disp) ->
    gen_server:call(Disp, get_socket).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(#config{}) ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Bot) ->
    Name = binary_to_atom(<<(Bot#config.server)/binary, ":disp">>, latin1),
    gen_server:start_link({local, Name}, ?MODULE, [Bot], []).

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
init([Bot]) ->
    lager:info("Start disp for bot ~p!!!", [Bot]),
    gen_server:cast(self(), connect), %% Start dialog with server.
    {ok, #state{name = Bot#config.name, 
		server = Bot#config.server,
		pass = Bot#config.pass,
		config_rooms = Bot#config.rooms}}.

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
handle_call(get_rooms, _From, #state{rooms=Rooms}=State) ->
    {reply, {ok, Rooms}, State};

handle_call(get_socket, _From, #state{socket=Socket}=State) ->
    {reply, {ok, Socket}, State};

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
handle_cast(connect, #state{server=Server, name=Name}=State) ->
    {ok, Socket} = gen_tcp:connect(binary_to_list(Server), 5222, [binary,
								  {keepalive, true},
								  {active, true},
								  {packet, 0},
								  {reuseaddr, true}]),
    ok = gen_tcp:controlling_process(Socket, self()),
    Message = xml_packet(stream, {Name, Server}),
    gen_server:cast(self(), {send, Message}),
    gen_server:cast(self(), start_rooms), %% Start rooms.
    {noreply, State#state{socket = Socket}};

handle_cast({send, Data}, #state{socket=Socket}=State) ->
    lager:info("Data ~p socket ~p", [Data, Socket]),
    ok = gen_tcp:send(Socket, Data),
    {noreply, State};

handle_cast({new_stream, Data}, #state{socket=Socket}=State) ->
    lager:info("New stream ~p socket ~p", [Data, Socket]),
    ok = gen_tcp:send(Socket, Data),
    {noreply, State#state{xml_stream = undefined}};

%% handle_cast({stop, Data}, #state{socket=Socket}=State) ->
%%     Message0 = xml_packet(presence, <<"unavailable">>),
%%     gen_server:cast(self(), {send, Message0}),
%%     Message1 = xml_packet(close, stream),
%%     gen_server:cast(self(), {send, Message1}),
%%     {stop, State};

handle_cast(start_rooms, #state{socket=Socket, name=Name, server=Server, 
				config_rooms=CRooms}=State) ->
    Rooms =
	[ begin
	      Pid = yebot_worker_sup:start_worker(Socket, Name, Server, Room),
	      {Room, Pid}
	  end || Room <- CRooms ],
    {noreply, State#state{rooms = Rooms}};

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
handle_info({tcp, _Socket, Data}, #state{xml_stream=undefined}=State) ->
    {ok, Parser0} = exml_stream:new_parser(),
    {ok, Parser1, Xml} = exml_stream:parse(Parser0, Data),
    %% lager:info("Xml ~p", [Xml]),
    parse_xml(Xml, State),
    {noreply, State#state{xml_stream = Parser1}};

handle_info({tcp, _Socket, Data}, #state{xml_stream=Parser0}=State) ->
    {ok, Parser1, Xml} = exml_stream:parse(Parser0, Data),
    lager:info("GET TCP Xml ~p", [Xml]),
    parse_xml(Xml, State),
    {noreply, State#state{xml_stream = Parser1}};

handle_info({tcp_closed, _Socket}, State) ->
    {stop, tcp_closed, State};

handle_info(connection_lost, State) ->
    {stop, tcp_closed, State};

handle_info({timer, XmlPacket}, State) ->
    {ok, TRef} = timer:send_after(?TIMER_ERROR_DELAY, connection_lost),
    gen_server:cast(self(), {send, XmlPacket}),
    {noreply, State#state{tref = TRef}};

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
terminate(Reason, #state{socket=Socket}=_State) ->
    lager:info("DISP STOP with reason ~p!!!", [Reason]),
    ok = gen_tcp:close(Socket),
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

%% Stream is started we need authenticated.
parse_xml([#xmlel{name= <<"stream:features">>, children=[#xmlel{name= <<"starttls">>}|_]}],
	  #state{name=Name, pass=Pass}=State) ->
    lager:info("State ~p", [State]),
    AuthPlain = xml_packet(auth, 'PLAIN', {Name, Pass}),
    gen_server:cast(self(), {send, AuthPlain});

%% Second stream is started we need bind it.
parse_xml([#xmlel{name= <<"stream:features">>}], _) ->
    lager:info("Second stream started!!"),
    XmlBind = xml_packet(bind, 121324567),
    gen_server:cast(self(), {send, XmlBind});

parse_xml([#xmlel{name= <<"success">>}], #state{name=Name, server=Server}) ->
    XmlPacket = xml_packet(stream, {Name, Server}),
    %% lager:info("New stream ~p", [XmlPacket]),
    gen_server:cast(self(), {new_stream, XmlPacket});

%% Session is started, we start rooms' workers.
parse_xml([#xmlel{name= <<"iq">>, attrs=[{<<"type">>, <<"result">>}|_]}]=Xml,
	  #state{rooms=Rooms, name=Name, server=Server}) ->
    lager:info("New sessions started, we are starting rooms ~p!!!", [Rooms]),
    %% Start ping scheduler
    ping_scheduler(Name, Server),
    [ begin
	  Pid ! {get_data, Xml}
      end || {_Room, Pid} <- Rooms ];

    
parse_xml([#xmlel{name= <<"iq">>, attrs=[{<<"from">>, AServer}|_]}],
	  #state{name = Name, server=Server, tref = TRef}) when AServer =:= Server ->
    lager:info("We got ping from ~p server!!", [Server]),
    %% First we cancel error TRef
    {ok, cancel} = timer:cancel(TRef),
    %% Start ping scheduler again
    ping_scheduler(Name, Server);

parse_xml([#xmlel{name= <<"iq">>}], _) ->
    XmlPacket = xml_packet(session, 123456576),
    gen_server:cast(self(), {send, XmlPacket});

parse_xml([#xmlel{name= <<"message">>}=Data]=Xml, #state{rooms=Rooms}=_State) ->
    From = exml_query:attr(Data, <<"from">>),
    [Room|_] = binary:split(From, <<"@">>),
    case proplists:get_value(Room, Rooms) of
	undefined -> 
	    lager:info("There isn't such started room ~p!!!", [Room]);
	Pid ->
	    Pid ! {get_data, Xml}
    end;

parse_xml(Data, _) ->
    lager:info("RECV XML: ~n~p~n", [Data]).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parse XML Packets
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

xml_packet(ping, {Name, Server}) ->
    JID = <<Name/binary, "@", Server/binary, "/erlang">>,
    <<"<iq from='", JID/binary, "' to='", Server/binary, "' id='c2s1' type='get'><ping xmlns='urn:xmpp:ping'/></iq>">>;

xml_packet(stream, {Name, Server}) ->
    JID = <<Name/binary, "@", Server/binary>>,
    <<"<stream:stream xmlns='jabber:client' from='", JID/binary, "' to='", Server/binary, "' version='1.0' xmlns:stream='http://etherx.jabber.org/streams' >">>;

xml_packet(bind, Id) ->
    <<"<iq type='set' id='97460001'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>erlang</resource> </bind></iq>">>;

xml_packet(session, Id) ->
    <<"<iq type='set' id='97460002'><session xmlns='urn:ietf:params:xml:ns:xmpp-session' /></iq>">>.

%% xml_packet(close, stream) ->
%%     <<"</stream:stream>">>;


xml_packet(auth, 'PLAIN', {Name, Password}) ->
    lager:info("Name ~p, Password ~p", [Name, Password]),
    BaseData = base64:encode(<<0, Name/binary, 0, Password/binary>>),
    <<"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>", BaseData/binary, "</auth>">>.


ping_scheduler(Name, Server) ->
    XmlPacket = xml_packet(ping, {Name, Server}),
    timer:send_after(?TIMER_DELAY, {timer, XmlPacket}).
