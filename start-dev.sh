#!/bin/sh
erl -boot start_sasl -config rel/files/sys.config -pa apps/*/ebin deps/*/ebin -s yebot_app start -sname yebot
