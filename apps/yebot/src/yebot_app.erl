-module(yebot_app).

-behaviour(application).

%% Application callbacks
-export([start/0, start/2, stop/1]).


start() ->
    application:start(yebot).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    yebot_sup:start_link().

stop(_State) ->
    ok.
