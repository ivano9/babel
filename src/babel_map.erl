-module(babel_map).
-include("babel.hrl").

-define(BADKEY, '$error_badkey').

-record(babel_map, {
    values = #{}        ::  #{key() => value()},
    updates = []        ::  ordsets:ordset(key()),
    removes = []        ::  ordsets:ordset(key()),
    context = undefined ::  riakc_datatype:context()
}).

-opaque t()             ::  #babel_map{}.
-type spec()            ::  #{riak_key() => babel_key() | type()}
                            | {register, type()}
                            | fun((encode, binary(), any()) -> value())
                            | fun((decode, binary(), value()) -> any()).
-type babel_key()       ::  {binary(), type()}.
-type riak_key()        ::  {binary(), datatype()}.
-type key_path()        ::  binary() | [binary()].
-type value()           ::  any().
-type datatype()        ::  counter | flag | register | set | map.
-type type()            ::  atom
                            | existing_atom
                            | boolean
                            | integer
                            | float
                            | binary
                            | list
                            | spec()
                            | babel_set:spec()
                            | fun((encode, any()) -> value())
                            | fun((decode, value()) -> any()).
-type update_fun()      ::  fun((babel_datatype() | term()) ->
                                babel_datatype() | term()
                            ).

-export_type([t/0]).
-export_type([spec/0]).
-export_type([key_path/0]).

%% API
-export([new/0]).
-export([new/1]).
-export([new/2]).
-export([from_riak_map/2]).
%% -export([to_riak_map/2]).
-export([to_riak_op/2]).
-export([type/0]).
-export([is_type/1]).
-export([get/2]).
-export([get/3]).
-export([set/3]).
-export([add_element/3]).
-export([update/3]).
-export([remove/2]).




%% =============================================================================
%% API
%% =============================================================================


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new() -> t().

new()->
    #babel_map{}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map()) -> t().

new(Data) when is_map(Data) ->
    #babel_map{values = Data}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: map(), Ctxt :: riakc_datatype:context()) -> t().

new(Data, Spec) when is_map(Data) ->
    MissingKeys = lists:subtract(maps:keys(Spec), maps:keys(Data)),
    Values = init_values(maps:with(MissingKeys, Spec), Data),
    #babel_map{values = Values}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_map(
    RMap :: riakc_map:crdt_map() | list(), Spec :: spec()) -> t().

from_riak_map({map, Values, _, _, Context}, Spec) ->
    from_riak_map(Values, Context, Spec).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(T :: t(), Spec :: spec()) ->
    riakc_datatype:update(riakc_map:map_op()).

to_riak_op(T, Spec0) when is_map(Spec0) ->
    %% #{Key => {{_, _} = RKey, Spec}}
    Spec = reverse_spec(Spec0),

    Updated = maps:with(T#babel_map.updates, T#babel_map.values),

    FoldFun = fun
        ToOp({{_, counter}, _KeySpec}, _V, _Acc) ->
            error(not_implemented);

        ToOp({{_, flag}, _KeySpec}, _V, _Acc) ->
            error(not_implemented);

        ToOp({_, register}, undefined, Acc) ->
            Acc;

        ToOp({{_, register} = RKey, KeySpec}, Value, Acc) ->
            Bin = to_binary(Value, KeySpec),
            [{riakc_register:type(), {assign, Bin}, undefined} | Acc];

        ToOp({{_, set} = RKey, KeySpec}, Set, Acc) ->
            case babel_set:to_riak_op(Set, KeySpec) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp({{_, map} = RKey, KeySpec}, Map, Acc) ->
            case to_riak_op(Map, KeySpec) of
                undefined -> Acc;
                {_, Op, _} -> [{update, RKey, Op} | Acc]
            end;

        ToOp(Key, Value, Acc) ->
            ToOp(maps:get(Key, Spec), Value, Acc)

    end,
    Updates = maps:fold(FoldFun, [], Updated),

    Result = lists:append(
        [{remove, Key} || Key <- T#babel_map.removes],
        Updates
    ),

    case Result of
        [] ->
            undefined;
        _ ->
            {riakc_map:type(), {update, Result}, T#babel_map.context}
    end.


%% -----------------------------------------------------------------------------
%% @doc %% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> atom().

type() -> map.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_map).


%% -----------------------------------------------------------------------------
%% @doc Returns value `Value' associated with `Key' if `T' contains `Key'.
%% `Key' can be a binary or a path represented as a list of binaries, or as a
%% tuple of binaries.
%%
%% The call fails with a {badarg, `T'} exception if `T' is not a a Babel Map.
%% It also fails with a {badkey, `Key'} exception if no value is associated
%% with `Key'.
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key(), T :: t()) -> any().

get(Key, T) ->
    get(Key, T, ?BADKEY).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get(Key :: key_path(), Map :: t(), Default :: any()) -> value().

get([], _, _) ->
    error(badkey);

get(_, #babel_map{values = V}, Default) when map_size(V) == 0 ->
    maybe_badkey(Default);

get([H|[]], #babel_map{} = Map, Default) ->
    get(H, Map, Default);

get([H|T], #babel_map{values = V}, Default) ->
    case maps:find(H, V) of
        {ok, Child} ->
            get(T, Child, Default);
        error ->
            maybe_badkey(Default)
    end;

get(K, #babel_map{values = V}, Default) ->
    case maps:find(K, V) of
        {ok, Value} ->
            Value;
        {ok, Value} ->
            case babel_set:is_type(Value) of
                true ->
                    babel_set:value(Value);
                false ->
                    Value
            end;
        error ->
            maybe_badkey(Default)
    end;

get(_, _, _) ->
    error(badarg).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec set(Key :: key(), Value :: value(), Map :: t()) -> t() | no_return().

set([H|[]], Value, Map) ->
    set(H, Value, Map);

set([H|T], Value, #babel_map{} = Map0) ->
    InnerMap = case get(H, Map0, undefined) of
        #babel_map{} = HMap -> HMap;
        undefined -> new();
        Term -> error({badmap, Term})
    end,
    Map = Map0#babel_map{
        updates = ordsets:add_element(H, Map0#babel_map.updates)
    },
    set(H, set(T, Value, InnerMap), Map);

set([], _, _)  ->
    error(badkey);

set(Key, Value, #babel_map{} = Map) when is_binary(Key) ->
    Map#babel_map{
        values = maps:put(Key, Value, Map#babel_map.values),
        updates = ordsets:add_element(Key, Map#babel_map.updates)
    };

set(_, _, _) ->
    error(badarg).


%% -----------------------------------------------------------------------------
%% @doc Adds a value to a babel set associated with key or path `Key'.
%% An exception is generated if the initial value associated with `Key' is not
%% a babel set.
%% @end
%% -----------------------------------------------------------------------------
-spec add_element(Key :: key(), Value :: value(), Map :: t()) ->
    t() | no_return().

add_element([H|[]], Value, Map) ->
    add_element(H, Value, Map);

add_element([H|T], Value, #babel_map{} = Map0) ->
    InnerMap = case get(H, Map0, undefined) of
        #babel_map{} = HMap -> HMap;
        undefined -> new();
        Term -> error({badmap, Term})
    end,
    Map = Map0#babel_map{
        updates = ordsets:add_element(H, Map0#babel_map.updates)
    },
    set(H, add_element(T, Value, InnerMap), Map);

add_element([], _, _)  ->
    error(badkey);

add_element(Key, Value, #babel_map{context = C} = Map) when is_binary(Key) ->
    NewValue = case get(Key, Map, undefined) of
        undefined ->
            babel_set:new([Value], C);
        Term ->
            case babel_set:is_type(Term) of
                true ->
                    babel_set:add_element(Value, Term);
                false ->
                    error({badarg, Key, Term})
            end
    end,
    Map#babel_map{
        values = maps:put(Key, NewValue, Map#babel_map.values),
        updates = ordsets:add_element(Key, Map#babel_map.updates)
    };

add_element(_, _, _) ->
    error(badarg).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(Key :: key(), Fun :: update_fun(), T :: t()) -> NewT :: t().

update(Key, Fun, #babel_map{values = V, updates = U} = Map) ->
    Map#babel_map{
        values = maps:put(Key, Fun(maps:get(Key, V)), V),
        updates = ordsets:add_element(Key, U)
    }.



%% -----------------------------------------------------------------------------
%% @doc Removes a key and its value from the map. Removing a key that
%% does not exist simply records a remove operation.
%% @throws context_required
%% -----------------------------------------------------------------------------
-spec remove(Key :: key(), T :: t()) -> NewT :: t() | no_return().

remove(_, #babel_map{context = undefined}) ->
    throw(context_required);

remove(Key, T) ->
    T#babel_map{
        values = maps:remove(Key, T#babel_map.values),
        removes = ordsets:add_element(Key, T#babel_map.removes)
    }.




%% =============================================================================
%% PRIVATE
%% =============================================================================



%% @private
from_riak_map(RMap, Context, Spec) when is_map(Spec) ->
     %% Convert values in RMap
    Convert = fun({Key, _} = RKey, RValue, Acc) ->
        case maps:find(RKey, Spec) of
            {ok, {NewKey, TypeOrFun}} ->
                Value = from_datatype(RKey, RValue, TypeOrFun),
                maps:put(NewKey, Value, Acc);
            {ok, TypeOrFun} ->
                Value = from_datatype(RKey, RValue, TypeOrFun),
                maps:put(Key, Value, Acc);
            error ->
                error({missing_spec, RKey})
        end
    end,
    Values0 = orddict:fold(Convert, maps:new(), RMap),

    %% Initialise values for Spec kyes not present in RMap
    MissingKeys = lists:subtract(maps:keys(Spec), orddict:fetch_keys(RMap)),
    Values1 = init_values(maps:with(MissingKeys, Spec), Values0),

    #babel_map{values = Values1, context = Context};

from_riak_map(RMap, Context, Fun) when is_function(Fun, 3) ->
    %% This is equivalent to a map function.
    Values = riakc_map:fold(
        fun(K, V, Acc) ->
            maps:put(K, Fun(decode, K, V), Acc)
        end,
        maps:new(),
        RMap
    ),
    #babel_map{values = Values, context = Context};

from_riak_map(RMap, Context, Type) ->
    %% This is equivalent to a map function where we assume all keys in the map
    %% to be a register of the same type.
    Fun = fun(decode, _, V) -> babel_utils:from_binary(V, Type) end,
    from_riak_map(RMap, Context, Fun).


%% @private
init_values(Spec, Acc) ->
    Fun = fun
        ({_, counter}, {_Key, _KeySpec}, _) ->
            %% from_integer(<<>>, KeySpec)
            error(not_implemented);
        ({Key, counter}, KeySpec, _) ->
            error(not_implemented);
        ({_, flag}, {_Key, _KeySpec}, _) ->
            %% from_boolean(<<>>, KeySpec)
            error(not_implemented);
        ({Key, flag}, KeySpec, _) ->
            error(not_implemented);
        ({_, register}, {Key, KeySpec}, Acc) ->
            maps:put(Key, from_binary(<<>>, KeySpec), Acc);
        ({Key, register}, KeySpec, Acc) ->
            maps:put(Key, from_binary(<<>>, KeySpec), Acc);
        ({_, set}, {Key, KeySpec}, Acc) ->
            maps:put(Key, babel_set:new([]), Acc);
        ({Key, set}, KeySpec, Acc) ->
            maps:put(Key, babel_set:new([]), Acc);
        ({_, map}, {Key, KeySpec}, Acc) when is_map(KeySpec) ->
            maps:put(Key, babel_map:new(#{}, KeySpec), Acc);
        ({_, map}, {Key, KeySpec}, Acc) ->
            maps:put(Key, babel_map:new(#{}), Acc);
        ({Key, map}, KeySpec, Acc) when is_map(KeySpec) ->
            maps:put(Key, babel_map:new(#{}, KeySpec), Acc);
        ({Key, map}, KeySpec, Acc) ->
            maps:put(Key, babel_map:new(#{}), Acc)
    end,
    maps:fold(Fun, Acc, Spec).


%% @private
from_datatype({_, register} = Key, Value, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_datatype({_, register} = Key, Value, Type) ->
    babel_utils:from_binary(Value, Type);

from_datatype({_, set} = Key, Value, #{binary := _} = Spec) ->
    babel_set:from_riak_set(Value, Spec);

from_datatype({_, map} = Key, Value, Spec) ->
    from_riak_map(Value, undefined, Spec);

from_datatype(_Key, _RiakMap, _Type) ->
    error(not_implemented).



%% @private
from_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(decode, Value);

from_binary(Value, Type) ->
    babel_utils:from_binary(Value, Type).


%% @private
to_binary(Value, Fun) when is_function(Fun, 2) ->
    Fun(encode, Value);

to_binary(Value, Type) ->
    babel_utils:to_binary(Value, Type).


reverse_spec(Spec) ->
    maps:fold(
        fun
            (RKey, {Key, Spec}, Acc) ->
                maps:put(Key, {RKey, Spec}, Acc);
            ({Key, _} = RKey, Spec, Acc) ->
                maps:put(Key, {RKey, Spec}, Acc)
        end,
        maps:new(),
        Spec
    ).


%% @private
maybe_badkey(?BADKEY) ->
    error(badkey);

maybe_badkey(Term) ->
    Term.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_type(Term :: any()) -> counter | flag | set | map | term.

get_type(Term) ->
    Fun = fun(Mod, Acc) ->
        try
            Type = Mod:type(Term),
            throw({type, Type})
        catch
            error:_ -> Acc
        end
    end,

    try
        lists:foldl(
            Fun,
            term,
            [babel_counter, babel_flag, babel_set, babel_map]
        )
    catch
        throw:{type, Mod} -> Mod
    end.