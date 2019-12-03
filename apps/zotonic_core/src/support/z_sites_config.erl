%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2019 Marc Worrell
%% @doc Load and manage site configuration files.

%% Copyright 2019 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(z_sites_config).

-export([
    app_is_site/1,
    config_files/1,
    config_files/2,
    read_configs/1
    ]).

-define(CONFIG_FILE, "zotonic_site.*").

-spec app_is_site( atom() ) -> boolean().
app_is_site( App ) ->
    filelib:is_regular( site_config_file( App ) ).

%% @doc Return the main configuration file for a site
-spec site_config_file( atom() ) -> file:filename_all() | {error, bad_name}.
site_config_file(Site) ->
    case z_path:site_dir(Site) of
        {error, _} = Error ->
            Error;
        SiteDir ->
            Files = filelib:wildcard( filename:join([ SiteDir, "priv", ?CONFIG_FILE ]) ),
            Files1 = lists:filter(
                fun(F) ->
                    case filename:extension(F) of
                        ".config" -> true;
                        ".yaml" -> true;
                        ".yml" -> true;
                        ".json" -> true;
                        _ -> false
                    end
                end,
                Files),
            case Files1 of
                [] -> {error, bad_name};
                [ File | _ ] -> File
            end
    end.

-spec config_files( atom() ) -> list( file:filename_all() ).
config_files( Site ) ->
    config_files( node(), Site ).

-spec config_files( node(), atom() ) -> list( file:filename_all() ).
config_files(Node, Site) ->
    case site_config_file(Site) of
        {error, _} ->
            [];
        ConfigFile ->
            SitePrivDir = filename:dirname(ConfigFile),
            case z_config_files:config_dir(Node) of
                {ok, ConfigDir} ->
                    [ ConfigFile ]
                    ++ z_config_files:files( filename:join([ ConfigDir, "site_config.d", Site ]) )
                    ++ z_config_files:files( filename:join([ SitePrivDir, "config.d" ]) );
                {error, _} ->
                    [ ConfigFile ]
                    ++ z_config_files:files( filename:join([ SitePrivDir, "config.d" ]) )
            end
    end.


-spec read_configs( [ file:filename_all() ] ) -> {ok, map()} | {error, term()}.
read_configs(Fs) when is_list(Fs) ->
    lists:foldl(
        fun
            (_, {error, _} = Error) ->
                Error;
            (F, {ok, Acc}) ->
                case z_config_files:consult(F) of
                    {ok, Data} ->
                        apps_config(F, Data, Acc);
                    {error, _} = Error ->
                        Error
                end
        end,
        {ok, #{}},
        Fs).

apps_config(File, Data, Cfgs) when is_list(Data) ->
    lists:foldl(
        fun
            (AppConfig, Acc) when is_map(AppConfig) ->
                maps:fold(
                    fun
                        (Key, Cfg, {ok, MAcc}) ->
                            {ok, MAcc#{ Key => Cfg }};
                        (_Key, _Cfg, {error, _} = Error) ->
                            Error
                    end,
                    {ok, Acc},
                    AppConfig);
            (AppConfig, Acc) when is_list(AppConfig) ->
                lists:foldl(
                    fun
                        ({Key, Cfg}, {ok, MAcc}) ->
                            {ok, MAcc#{ Key => Cfg }};
                        (Key, {ok, MAcc}) when is_atom(Key) ->
                            {ok, MAcc#{ Key => true }};
                        (Other, {ok, _}) ->
                            {error, {config_file, format, File, {unknown_term, Other}}};
                        (_, {error, _} = Error) ->
                            Error
                    end,
                    {ok, Acc},
                    AppConfig)
        end,
        Cfgs,
        Data).