-module(babel_crdt).

-define(BADKEY, '$error_badkey').

-export([map_entry/3]).
-export([dirty_fetch/2]).

-export([to_integer/1]).
-export([register_to_term/1]).
-export([register_to_binary/1]).
-export([register_to_integer/1]).
-export([register_to_integer/2]).
-export([register_to_atom/2]).
-export([register_to_existing_atom/2]).

-compile({no_auto_import, [get/1]}).


%% =============================================================================
%% API
%% =============================================================================

to_integer(Object) ->
    try riakc_datatype:module_for_type(Object) of
        riakc_register ->
            binary_to_integer(riakc_register:value(Object));
        riakc_counter ->
            riakc_register:value(Object)
    catch
        error:function_clause ->
            error(badarg)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec register_to_binary(riakc_register:register()) -> binary() | no_return().

register_to_binary(Object) ->
    riakc_register:value(Object).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec register_to_integer(riakc_register:register()) -> integer() | no_return().

register_to_integer(Object) ->
    binary_to_integer(riakc_register:value(Object)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec register_to_integer(riakc_register:register(), Base :: 2..36) ->
    integer() | no_return().

register_to_integer(Object, Base) ->
    binary_to_integer(riakc_register:value(Object), Base).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec register_to_atom(
    riakc_register:register(), Encoding :: latin1 | unicode | utf8) ->
    atom() | no_return().

register_to_atom(Object, Encoding) ->
    binary_to_atom(riakc_register:value(Object), Encoding).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec register_to_existing_atom(
    riakc_register:register(), Encoding :: latin1 | unicode | utf8) ->
    atom() | no_return().

register_to_existing_atom(Object, Encoding) ->
    binary_to_existing_atom(riakc_register:value(Object), Encoding).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec register_to_term(riakc_register:register()) -> term() | no_return().

register_to_term(Object) ->
    binary_to_term(riakc_register:value(Object)).


%% -----------------------------------------------------------------------------
%% @doc Returns the "unwrapped" value associated with the key in the
%% map. As opposed to riakc_map:fetch/2 this function searches for the key in
%% the removed and updated private structures of the map first. If the key was
%% found on the removed set, fails with a `removed' exception. If they key was
%% in the updated set, it returns the updated value otherwise calls
%% riakc_map:fetch/2.
%%
%% @end
%% -----------------------------------------------------------------------------
-spec dirty_fetch(riakc_map:key(), riakc_map:crdt_map()) -> term().

dirty_fetch(Key, {map, _, Updates, Removes, _} = Map) ->
    case ordsets:is_element(Key, Removes) of
        true ->
            error(removed);
        false ->
            case orddict:find(Key, Updates) of
                {ok, Value} ->
                    Value;
                error ->
                    riakc_map:fetch(Key, Map)
            end
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec map_entry(
    Type :: riakc_datatype:typename(),
    Field :: binary(),
    Value :: binary() | list()) ->
    riakc_map:raw_entry().

map_entry(register, Field, Value) ->
    {{Field, register}, riakc_register:new(Value, undefined)};

map_entry(counter, Field, Value) ->
    {{Field, counter}, riakc_counter:new(Value, undefined)};

map_entry(set, Field, Values) when is_list(Values) ->
    {{Field, set}, riakc_set:new(Values, undefined)};

map_entry(map, Field, Values) when is_list(Values) ->
    {{Field, map}, riakc_map:new(Values, undefined)}.