#!/bin/sh
erl -config rel/files/sys.config -pa apps/*/ebin deps/*/ebin -s lager -s yebot_app -s -sname yebot
