%% @author Arjan Scherpenisse <arjan@scherpenisse.net>
%% @copyright 2009 Arjan Scherpenisse <arjan@scherpenisse.net>
%% Date: 2009-10-01
%% @doc Entrypoint for obtaining an oauth access token.

%% Copyright 2009 Arjan Scherpenisse
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

-module(controller_oauth_access_token).

-author("Arjan Scherpenisse <arjan@scherpenisse.net>").

-export([
         init/1,
         resource_exists/2,
         allowed_methods/2,
         content_types_provided/2,
         process_post/2,
         response/2
        ]).

-include_lib("controller_webmachine_helper.hrl").
-include_lib("zotonic.hrl").



init(_Args) ->
    {ok, []}.


resource_exists(ReqData, _Context) ->
    Context  = z_context:new_request(ReqData, [], ?MODULE),
    Context1 = z_context:ensure_qs(Context),
    Context2 = z_context:set_noindex_header(Context1),
    {true, ReqData, Context2}.


allowed_methods(ReqData, Context) ->
    {['POST', 'GET', 'HEAD'], ReqData, Context}.


content_types_provided(ReqData, Context) ->
    {[{"text/html", response}], ReqData, Context}.


process_post(ReqData, Context) ->
    response(ReqData, Context).

response(ReqData, Context) ->
    case mod_oauth:request_is_signed(ReqData) of
        false ->
            % Request was not signed.
            mod_oauth:authenticate("Not an OAuth request.", ReqData, Context);
        true ->
            mod_oauth:serve_oauth(ReqData, Context,
                fun(URL, Params, Consumer, Signature) ->
                        case mod_oauth:str_value("oauth_token", Params) of
                            undefined ->
                                mod_oauth:authenticate("Missing oauth_token.", ReqData, Context);
                            ParamToken ->
                                case m_oauth_app:secrets_for_verify(request, Consumer, ParamToken, Context) of
                                    undefined ->
                                        mod_oauth:authenticate("Request token not found.", ReqData, Context);
                                    Token ->
                                        case mod_oauth:verify(ReqData, URL, Params, Consumer, Signature, Token) of
                                            true ->
                                                case m_oauth_app:exchange_request_for_access(Token, Context) of
                                                    {ok, NewToken} ->
                                                        ReqData1 = wrq:set_resp_body(oauth:uri_params_encode(
                                                                                       [{"oauth_token", binary_to_list(proplists:get_value(token, NewToken))},
                                                                                        {"oauth_token_secret", binary_to_list(proplists:get_value(token_secret, NewToken))}]), ReqData),
                                                        {{halt, 200}, ReqData1, Context};

                                                    {false, Reason} ->
                                                        mod_oauth:authenticate(Reason, ReqData, Context)
                                                end;
                                            false ->
                                                mod_oauth:authenticate("Signature verification failed.", ReqData, Context)
                                        end
                                end
                        end
                end
           )
    end.

