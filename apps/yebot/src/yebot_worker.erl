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
-export([start_link/3]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
	  server :: binary(),
	  room :: binary(),
	  name :: binary()
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
-spec(start_link(binary(), binary(), binary()) ->
	     {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Name, Server, Room) ->
    gen_server:start_link(?MODULE, [Name, Server, Room], []).

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
init([Name, Server, Room]) ->
    %% gen_server:cast(self(), connect),
    {ok, #state{name = Name, server = Server, room = Room}}.

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
%% handle_cast(connect, #state{server=Server, name=Name}=State) ->
%%     {ok, Socket} = gen_tcp:connect(binary_to_list(Server), 5222, [binary, 
%% 						  {active, true},
%% 						  {packet, 0},
%% 						  {reuseaddr, true}]),
%%     ok = gen_tcp:controlling_process(Socket, self()),
%%     Message = xml_packet(stream, {Name, Server}),
%%     gen_server:cast(self(), {send, Message}),
%%     {noreply, State#state{socket = Socket}};

%% handle_cast({send, Data}, #state{socket=Socket}=State) ->
%%     lager:info("Data ~p socket ~p", [Data, Socket]),
%%     ok = gen_tcp:send(Socket, Data),
%%     {noreply, State};

%% handle_cast({new_stream, Data}, #state{socket=Socket}=State) ->
%%     lager:info("New stream ~p socket ~p", [Data, Socket]),
%%     ok = gen_tcp:send(Socket, Data),
%%     {noreply, State#state{xml_stream = undefined}};

%% handle_cast({stop, Data}, #state{socket=Socket}=State) ->
%%     Message0 = xml_packet(presence, <<"unavailable">>),
%%     gen_server:cast(self(), {send, Message0}),
%%     Message1 = xml_packet(close, stream),
%%     gen_server:cast(self(), {send, Message1}),
%%     {stop, State};

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
%% handle_info({tcp, _Socket, Data}, #state{xml_stream=undefined}=State) ->
%%     {ok, Parser0} = exml_stream:new_parser(),
%%     {ok, Parser1, Xml} = exml_stream:parse(Parser0, Data),
%%     %% lager:info("Xml ~p", [Xml]),
%%     parse_xml(Xml, State),
%%     {noreply, State#state{xml_stream = Parser1}};

%% handle_info({tcp, _Socket, Data}, #state{xml_stream=Parser0}=State) ->
%%     {ok, Parser1, Xml} = exml_stream:parse(Parser0, Data),
%%     lager:info("GET TCP Xml ~p", [Data]),
%%     parse_xml(Xml, State),
%%     {noreply, State#state{xml_stream = Parser1}};

%% handle_info({tcp_closed, _Socket}, State) ->
%%     {stop, tcp_closed, State};

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
terminate(Reason,_State) ->
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

%% Stream is started we need authenticated.
%% parse_xml([#xmlel{name= <<"stream:features">>, children=[#xmlel{name= <<"starttls">>}|_]}],
%% 	  #state{name=Name, pass=Pass}=State) ->
%%     %% lager:info("State ~p", [State]),
%%     AuthPlain = xml_packet(auth, 'PLAIN', {Name, Pass}),
%%     gen_server:cast(self(), {send, AuthPlain});

%% %% Second stream is started we need bind it.
%% parse_xml([#xmlel{name= <<"stream:features">>}], _) ->
%%     lager:info("Second stream started!!"),
%%     XmlBind = xml_packet(bind, 121324567),
%%     gen_server:cast(self(), {send, XmlBind});

%% parse_xml([#xmlel{name= <<"success">>}], #state{name=Name, server=Server}) ->
%%     XmlPacket = xml_packet(stream, {Name, Server}),
%%     %% lager:info("New stream ~p", [XmlPacket]),
%%     gen_server:cast(self(), {new_stream, XmlPacket});

%% parse_xml([#xmlel{name= <<"iq">>, attrs=[{<<"type">>, <<"result">>}|_]}],
%% 	  #state{name = Name, server = Server, room = Room}) ->
%%     lager:info("New sessions started!!"),
%%     XmlPacket = xml_packet(presence, {Name, Server, Room}),
%%     gen_server:cast(self(), {send, XmlPacket});

%% parse_xml([#xmlel{name= <<"iq">>}], _) ->
%%     XmlPacket = xml_packet(session, 123456576),
%%     gen_server:cast(self(), {send, XmlPacket});

%% parse_xml([#xmlel{name= <<"message">>}=Data], #state{name=Name}=State) ->
%%     Body = exml_query:subelement(Data, <<"body">>),
%%     CData = exml_query:cdata(Body),
%%     case binary:match(CData, Name) of
%% 	nomatch -> parse_xml(Data, State);
%% 	_ ->
%% 	    From = exml_query:attr(Data, <<"from">>),
%% 	    XmlPacket = xml_packet(message, {<<"pong">>, From}),
%% 	    gen_server:cast(self(), {send, XmlPacket})
%%     end;


%% parse_xml(Data, _) ->
%%     lager:info("RECV XML: ~n~p~n", [Data]).


%% xml_packet(stream, {Name, Server}) ->
%%     <<"<stream:stream xmlns='jabber:client' from='", (<<Name/binary, "@", Server/binary>>)/binary, "' to='", Server/binary, "' version='1.0' xmlns:stream='http://etherx.jabber.org/streams' >">>;

%% xml_packet(bind, Id) ->
%%     <<"<iq type='set' id='97460001'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>erlang</resource> </bind></iq>">>;

%% xml_packet(session, Id) ->
%%     <<"<iq type='set' id='97460002'><session xmlns='urn:ietf:params:xml:ns:xmpp-session' /></iq>">>;

%% xml_packet(presence, <<"unavailable">> =Status) ->
%%     <<"<presence xmlns='jabber:client' type='", Status/binary, "' />">>;

%% xml_packet(presence, {Name, Server, Room}) ->
%%     <<"<presence from='", Name/binary, "@", Server/binary, "/erlang' id='97460003' to='", Room/binary, "@conference.", Server/binary, "/", Name/binary, "'><x xmlns='http://jabber.org/protocol/muc' /></presence>">>;

%% xml_packet(close, stream) ->
%%     <<"</stream:stream>">>;

%% xml_packet(message, {Msg, To}) ->
%%     <<"<message to='.conf@conference.jabber.ru' from='yebot@jabber.ru/erlang' type='groupchat'><body>", Msg/binary,"</body></message>">>.


%% xml_packet(auth, 'PLAIN', {Name, Password}) ->
%%     lager:info("Name ~p, Password ~p", [Name, Password]),
%%     BaseData = base64:encode(<<0, Name/binary, 0, Password/binary>>),
%%     %% BaseData = <<"AHllYm90AEh1ZWJlcjEy">>,
%%     <<"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>", BaseData/binary, "</auth>">>.
