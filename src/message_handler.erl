-module(message_handler).

-include_lib("exmpp/include/exmpp.hrl").
-include_lib("exmpp/include/exmpp_client.hrl").
-include("ecomponent.hrl").

%% API
-export([pre_process_message/4]).

-spec pre_process_message( 
    Type::undefined | string(), 
    Message::term(), 
    From::ecomponent:jid(),
    ServerID::atom()) -> ok.

pre_process_message(undefined, Message, From, ServerID) ->
    forward(#message{
        type="normal", from=From, xmlel=Message, server=ServerID});
pre_process_message("error", Message, From, ServerID) ->
    forward_response(#message{
        type="error", from=From, xmlel=Message, server=ServerID});
pre_process_message(Type, Message, From, ServerID) ->
    forward(#message{
        type=Type, from=From, xmlel=Message, server=ServerID}).

-spec forward( Message::#message{} ) -> ok.

forward(Message) ->
    case ecomponent:get_message_processor() of
        undefined -> 
            spawn(processor, process_message, [Message]);
        {mod, P} ->
            spawn(P, process_message, [Message]);
        {app, Name} ->
            PID = whereis(Name),            
            case erlang:is_pid(PID) andalso erlang:is_process_alive(PID) of
                true -> 
                    PID ! Message;
                _ -> 
                    lager:warning("Process not Alive for Message: ~p~n", [Message])
            end;
        Proc -> 
            lager:warning("Unknown Request to Forward: ~p ~p~n", [Proc, Message])
    end.

-spec forward_response( Message::#message{} ) -> ok.

forward_response(#message{xmlel=Xmlel}=Message) ->
    ID = exmpp_stanza:get_id(Xmlel),
    case ecomponent:get_processor(ID) of
        undefined ->
            spawn(processor, process_message, [Message]);
        #matching{processor=undefined} ->
            spawn(processor, process_message, [Message]);
        #matching{processor=App} ->
            PID = whereis(App),
            case is_pid(PID) of 
                true ->
                    PID ! Message;
                _ -> 
                    lager:warning("Process not Alive for Message: ~p~n", [Message])
            end;
        Proc ->
            lager:warning("Unknown Request to Forward: ~p ~p~n", [Proc, Message])
    end.
