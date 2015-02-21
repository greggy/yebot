#!/bin/sh
erl -config rel/files/sys.config -pa apps/*/ebin deps/*/ebin -s yebot_app -s lager -s exmpp start -sname yebot
