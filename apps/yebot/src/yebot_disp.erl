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
	  mechanism :: binary(),
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
		mechanism = Bot#config.mechanism,
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
handle_cast(connect, #state{server=Server}=State) ->
    {ok, Socket} = gen_tcp:connect(binary_to_list(Server), 5222, [binary,
								  {keepalive, true},
								  {active, true},
								  {packet, 0},
								  {reuseaddr, true}]),
    ok = gen_tcp:controlling_process(Socket, self()),
    Message = xml_packet(stream, State),
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
    lager:info("NEW STREAM Xml ~p", [Xml]),
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
    XmlPacket = xml_packet(close, stream),
    gen_server:cast(self(), {send, XmlPacket}),
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

parse_xml([#xmlstreamstart{name= <<"stream:stream">>}=Data], State) ->
    %% Id = exml_query:attr(Data, <<"id">>),
    %% lager:info("GET SESSION ID ~p", [Id]),
    State;

%% Stream is started we need authenticated.
parse_xml([#xmlel{name= <<"stream:features">>,
		  children=[#xmlel{name= <<"starttls">>}|_]}=Xml],
	  #state{mechanism=Mech}=State) ->
    lager:info("State ~p, MECH ~p, LIST MECHS ~p", [State, Mech, list_mechanisms(Xml)]),
    case lists:member(Mech, list_mechanisms(Xml)) of
	false ->
	    make_auth(<<"PLAIN">>, State);
	true ->
	    make_auth(<<"DIGEST-MD5">>, State)
    end;

%% Second stream is started we need bind it.
parse_xml([#xmlel{name= <<"stream:features">>}], State) ->
    lager:info("Second stream started!!"),
    XmlBind = xml_packet(bind, State),
    gen_server:cast(self(), {send, XmlBind});

parse_xml([#xmlel{name= <<"success">>}], State) ->
    XmlPacket = xml_packet(stream, State),
    %% lager:info("New stream ~p", [XmlPacket]),
    gen_server:cast(self(), {new_stream, XmlPacket});

%% Session is started, we start rooms' workers.
parse_xml([#xmlel{name= <<"iq">>, attrs=[{<<"type">>, <<"result">>}|_]}]=Xml,
	  #state{rooms=Rooms}=State) ->
    lager:info("New sessions started, we are starting rooms ~p!!!", [Rooms]),
    %% Start ping scheduler
    ping_scheduler(State),
    [ Pid ! {get_data, Xml} || {_Room, Pid} <- Rooms ];

    
parse_xml([#xmlel{name= <<"iq">>, attrs=[{<<"from">>, AServer}|_]}],
	  #state{server=Server, tref=TRef}=State) when AServer =:= Server ->
    lager:info("We got ping from ~p server!!", [Server]),
    %% First we cancel error TRef
    {ok, cancel} = timer:cancel(TRef),
    %% Start ping scheduler again
    ping_scheduler(State);

parse_xml([#xmlel{name= <<"iq">>}], State) ->
    XmlPacket = xml_packet(session, State),
    gen_server:cast(self(), {send, XmlPacket});

%% DIGEST-MD5 Auth
parse_xml([#xmlel{name= <<"challenge">>}=Data], State) ->
    Bin = base64:decode(exml_query:cdata(Data)),
    Pl = challenge_to_pl(Bin),
    XmlPacket = 
	case proplists:get_value(<<"rspauth">>, Pl) of
	    undefined ->
		xml_packet(response, Pl, State);
	    _ ->
		xml_packet(response, State)
	end,
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
    lager:info("RECV UNHANDLED XML: ~n~p~n", [Data]).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% XML Packets
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

xml_packet(ping, #state{name=Name, server=Server}=_State) ->
    JID = <<Name/binary, "@", Server/binary, "/erlang">>,
    xmlel_to_stanza({xmlel, <<"iq">>, 
		     [{<<"from">>, JID}, {<<"to">>, Server},
		      {<<"id">>, <<"ping_1">>}, {<<"type">>, <<"get">>}],
		     [{xmlel, <<"ping">>, [{<<"xmlns">>, <<"urn:xmpp:ping">>}], []}]});

xml_packet(stream, #state{name=Name, server=Server}=_State) ->
    JID = <<Name/binary, "@", Server/binary>>,
    xmlel_to_stanza({xmlstreamstart, <<"stream:stream">>, 
		     [{<<"xmlns">>, <<"jabber:client">>}, {<<"from">>, JID}, {<<"to">>, Server},
		      {<<"version">>, <<"1.0">>}, 
		      {<<"xmlns:stream">>, <<"http://etherx.jabber.org/streams">>}]});

xml_packet(starttls, _State) ->
    xmlel_to_stanza({xmlel, <<"starttls">>, 
		     [{<<"xmlns">>, <<"urn:ietf:params:xml:ns:xmpp-tls">>}], []});

xml_packet(bind, _State) ->
    xmlel_to_stanza({xmlel, <<"iq">>, [{<<"type">>, <<"set">>}, {<<"id">>, <<"bind_1">>}],
		     [{xmlel, <<"bind">>, [{<<"xmlns">>, <<"urn:ietf:params:xml:ns:xmpp-bind">>}],
		       [{xmlel, <<"resource">>, [], [{xmlcdata, <<"erlang">>}]}]}]});

xml_packet(session, _State) ->
    xmlel_to_stanza({xmlel, <<"iq">>, 
		     [{<<"type">>, <<"set">>}, {<<"id">>, <<"session_1">>}],
		     [{xmlel, <<"session">>,
		       [{<<"xmlns">>, <<"urn:ietf:params:xml:ns:xmpp-session">>}], []}]});

xml_packet(response, _State) ->
    xmlel_to_stanza({xmlel, <<"response">>, 
		     [{<<"xmlns">>, <<"urn:ietf:params:xml:ns:xmpp-sasl">>}], []});

xml_packet(close, stream) ->
    xmlel_to_stanza({xmlsteamend, <<"stream:stream">>}).


xml_packet(auth, <<"PLAIN">>, #state{name=Name, pass=Password}=_State) ->
    lager:info("Name ~p, Password ~p", [Name, Password]),
    BaseData = base64:encode(<<0, Name/binary, 0, Password/binary>>),
    xmlel_to_stanza({xmlel, <<"auth">>, 
		     [{<<"xmlns">>, <<"urn:ietf:params:xml:ns:xmpp-sasl">>}, 
		      {<<"mechanism">>, <<"PLAIN">>}],
		     [{xmlcdata, BaseData}]});

xml_packet(auth, <<"DIGEST-MD5">>, _State) ->
    xmlel_to_stanza({xmlel, <<"auth">>, 
		     [{<<"xmlns">>, <<"urn:ietf:params:xml:ns:xmpp-sasl">>}, 
		      {<<"mechanism">>, <<"DIGEST-MD5">>}], []});

%% http://wiki.xmpp.org/web/SASLandDIGEST-MD5
xml_packet(response, Data, #state{name=Name, pass=Password, server=Server}=_State) ->
    lager:info("Data Proplists ~p", [Data]),
    A = erlang:md5(<<Name/binary, ":", Server/binary, ":", Password/binary>>),
    Nonce = proplists:get_value(<<"nonce">>, Data),
    Qop = proplists:get_value(<<"qop">>, Data),
    Charset = proplists:get_value(<<"charset">>, Data),
    CNonce = yebot_utils:random_number(),
    AuthzID = <<Name/binary, "@", Server/binary, "/erlang">>,
    B = yebot_utils:md5_hex(<<A/binary, ":", Nonce/binary, ":", CNonce/binary, ":", AuthzID/binary>>),
    C = yebot_utils:md5_hex(<<"AUTHENTICATE:xmpp/", Server/binary>>),
    D = yebot_utils:md5_hex(<<B/binary, ":", Nonce/binary, ":00000001:", 
			      CNonce/binary, ":", Qop/binary, ":", C/binary>>),
    E = pl_to_response([{<<"username">>, Name}, {<<"realm">>, Server}, {<<"nonce">>, Nonce},
			{<<"cnonce">>, CNonce}, {<<"nc">>, <<"00000001">>}, {<<"qop">>, Qop},
			{<<"digest-uri">>, <<"xmpp/", Server/binary>>}, {<<"response">>, D},
			{<<"charset">>, Charset}, {<<"authzid">>, AuthzID}]),
    lager:info("Response Data ~p", [E]),
    CData = base64:encode(E),
    xmlel_to_stanza({xmlel, <<"response">>,
		     [{<<"xmlns">>, <<"urn:ietf:params:xml:ns:xmpp-sasl">>}],
		     [{xmlcdata, CData}]}).



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Utils
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ping_scheduler(State) ->
    XmlPacket = xml_packet(ping, State),
    timer:send_after(?TIMER_DELAY, {timer, XmlPacket}).


xmlel_to_stanza(Xml) ->
    list_to_binary(exml:to_list(Xml)).


list_mechanisms(Xml) ->
    Mechs = exml_query:subelement(Xml, <<"mechanisms">>),
    #xmlel{children = Children} = Mechs,
    lists:foldl(fun(E, A) ->
			[exml_query:cdata(E)|A]
		end, [], Children).


make_auth(Method, State) ->
    AuthPacket = xml_packet(auth, Method, State),
    gen_server:cast(self(), {send, AuthPacket}).   


challenge_to_pl(Data) ->
    lists:foldl(fun(E, A) -> 
			[K, V] = binary:split(E, <<"=">>),
			[{K, binary:replace(V, <<"\"">>, <<"">>, [global])}|A]
		end, [], binary:split(Data, <<",">>, [global])).


pl_to_response(Data) ->
    lager:info("Data ~p", [Data]),
    lists:foldl(fun({K, V}, A) -> 
			<<K/binary, "=\"", V/binary, "\",", A/binary>>
		end, 
		begin 
		    {K, V} = hd(Data),
		    <<K/binary, "=\"", V/binary, "\"">> 
		end,
		tl(Data)).



%% TODO: Bot gets this message when smb kicks him
%% [{xmlel,<<"presence">>,[{<<"from">>,<<".conf@conference.jabber.ru/yebot">>},{<<"to">>,<<"yebot@jabber.ru/erlang">>},{<<"type">>,<<"unavailable">>}],[{xmlel,<<"x">>,[{<<"xmlns">>,<<"http://jabber.org/protocol/muc#user">>}],[{xmlel,<<"item">>,[{<<"affiliation">>,<<"member">>},{<<"role">>,<<"none">>}],[{xmlel,<<"reason">>,[],[{xmlcdata,<<208,191,209,136,208,181,208,187,32,208,189,208,176,209,133>>}]}]},{xmlel,<<"status">>,[{<<"code">>,<<"307">>}],[]}]}]}]
