%% =============================================================================
%%  babel_set.erl -
%%
%%  Copyright (c) 2020 Leapsight Holdings Limited. All rights reserved.
%%
%%  Licensed under the Apache License, Version 2.0 (the "License");
%%  you may not use this file except in compliance with the License.
%%  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%%  Unless required by applicable law or agreed to in writing, software
%%  distributed under the License is distributed on an "AS IS" BASIS,
%%  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%  See the License for the specific language governing permissions and
%%  limitations under the License.
%% =============================================================================

%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-module(babel_set).
-include("babel.hrl").

-record(babel_set, {
    values = []         ::  ordsets:ordset(any()),
    adds = []           ::  ordsets:ordset(any()),
    removes = []        ::  ordsets:ordset(any()),
    size = 0            ::  non_neg_integer(),
    context             ::  riakc_datatype:context() | undefined
}).

-opaque t()             ::  #babel_set{}.
-type type_spec()       ::  atom
                            | existing_atom
                            | boolean
                            | integer
                            | float
                            | binary
                            | list
                            | fun((encode, any()) -> binary())
                            | fun((decode, binary()) -> any()).

-export_type([t/0]).
-export_type([type_spec/0]).


%% API
-export([add_element/2]).
-export([add_elements/2]).
-export([context/1]).
-export([del_element/2]).
-export([fold/3]).
-export([from_riak_set/2]).
-export([is_element/2]).
-export([is_original_element/2]).
-export([is_type/1]).
-export([new/0]).
-export([new/1]).
-export([new/2]).
-export([original_value/1]).
-export([size/1]).
-export([to_riak_op/2]).
-export([type/0]).
-export([value/1]).



%% =============================================================================
%% API
%% =============================================================================




%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new() -> t().

new() ->
    new([]).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: ordsets:ordset(any())) -> t().

new(Data) when is_list(Data) ->
    Adds = ordsets:from_list(Data),
    #babel_set{adds = Adds, size = ordsets:size(Adds)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec new(Data :: ordsets:ordset(any()), Type :: type_spec())  -> t().

new(Data, _Type) when is_list(Data) ->
    %% TODO validate all elements are of type Type
    Adds = ordsets:from_list(Data),
    #babel_set{adds = Adds, size = ordsets:size(Adds)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @throws {badindex, term()}
%% @end
%% -----------------------------------------------------------------------------
-spec from_riak_set(
    RiakSet :: riakc_set:riakc_set() | ordsets:ordset(), Type :: type_spec()) ->
    maybe_no_return(t()).

from_riak_set(Ordset, Type) when is_list(Ordset) ->
    Values = [from_binary(E, Type) || E <- Ordset],
    new(Values);

from_riak_set(RiakSet, Type) ->
    Set = from_riak_set(riakc_set:value(RiakSet), Type),
    Set#babel_set{context = element(5, RiakSet)}.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec to_riak_op(T :: t(), Type :: type_spec()) ->
    riakc_datatype:update(riakc_set:set_op()).

to_riak_op(#babel_set{adds = [], removes = []}, _) ->
    undefined;

to_riak_op(#babel_set{adds = A, removes = [], context = C}, Type) ->
    {riakc_set:type(), {add_all, [to_binary(E, Type) || E <- A]}, C};

to_riak_op(#babel_set{adds = [], removes = R, context = C}, Type) ->
    {riakc_set:type(), {remove_all, [to_binary(E, Type) || E <- R]}, C};

to_riak_op(#babel_set{adds = A, removes = R, context = C}, Type) ->
    {
        riakc_set:type(),
        {update, [
            {remove_all, [to_binary(E, Type) || E <- R]},
            {add_all, [to_binary(E, Type) || E <- A]}
        ]},
        C
    }.


%% -----------------------------------------------------------------------------
%% @doc Returns the symbolic name of this container.
%% @end
%% -----------------------------------------------------------------------------
-spec type() -> set.

type() -> set.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_type(Term :: any()) -> boolean().

is_type(Term) ->
    is_record(Term, babel_set).


%% -----------------------------------------------------------------------------
%% @doc Returns the Riak KV context
%% @end
%% -----------------------------------------------------------------------------
-spec context(T :: t()) -> riakc_datatype:context().

context(#babel_set{context = Value}) -> Value.


%% -----------------------------------------------------------------------------
%% @doc Returns the original value of the set as an ordset.
%% This is equivalent to riakc_set:value/1 but where the elements are binaries
%% but of the type defined by the conversion `spec()' used to create the set.
%% @end
%% -----------------------------------------------------------------------------
-spec original_value(t()) -> ordsets:ordset(any()).

original_value(#babel_set{values = V}) -> V.


%% -----------------------------------------------------------------------------
%% @doc Returns the current value of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec value(T :: t()) -> ordsets:ordset(any()).

value(#babel_set{values = V, adds = A, removes = R}) ->
    ordsets:subtract(ordsets:union(V, A), R).


%% -----------------------------------------------------------------------------
%% @doc Returns the cardinality (size) of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec size(T :: t()) -> pos_integer().

size(#babel_set{size = Size}) -> Size.


%% -----------------------------------------------------------------------------
%% @doc Adds an element to the set.
%% You may add an element that already exists in the original set
%% value, but it does not count for the object's size calculation. Adding an
%% element that already exists is non-intuitive, but acts as a safety feature: a
%% client code path that requires an element to be present in the set
%% (or removed) can ensure that intended state by applying an
%% operation.
%% @end
%% -----------------------------------------------------------------------------
-spec add_element(Element :: any(), T :: t()) -> t().

add_element(Element, T) ->
    add_elements([Element], T).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add_elements(Elements :: [any()], T :: t()) -> t().

add_elements(Elements, #babel_set{adds = A0, size = S0} = T) ->
    A1 = lists:foldl(fun ordsets:add_element/2, A0, Elements),
    S1 = S0 + ordsets:size(A1) - ordsets:size(A0),

    T#babel_set{
        adds = A1,
        size = S1
    }.


%% -----------------------------------------------------------------------------
%% @doc Removes an element from the set.
%% You may remove an element that does not appear in the original
%% set value. This is non-intuitive, but acts as a safety feature: a
%% client code path that requires an element to be present in the set
%% (or removed) can ensure that intended state by applying an
%% operation.
%% @throws context_required
%% @end
%% -----------------------------------------------------------------------------
-spec del_element(Element :: any(), T :: t()) -> t() | no_return().

del_element(_, #babel_set{context = undefined}) ->
    throw(context_required);

del_element(Element, #babel_set{removes = R0, size = S0} = T) ->
    R1 = ordsets:add_element(Element, R0),
    S1 = S0 + ordsets:size(R1) - ordsets:size(R0),

    T#babel_set{
        removes = R1,
        size = S1
    }.


%% -----------------------------------------------------------------------------
%% @doc Folds over the members of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec fold(Fun :: fun((term(), term()) -> term()), Acc :: term(), T :: t()) ->
    Acc :: term().

fold(Fun, Acc0, T) ->
    ordsets:fold(Fun, Acc0, value(T)).


%% -----------------------------------------------------------------------------
%% @doc Test whether an element is a member of the set.
%% @end
%% -----------------------------------------------------------------------------
-spec is_element(binary(), riakc_set:riakc_set()) -> boolean().

is_element(Element, #babel_set{values = V, adds = A, removes = R}) ->
    not ordsets:is_element(Element, R) andalso
    (ordsets:is_element(Element, V) orelse ordsets:is_element(Element, A)).


%% -----------------------------------------------------------------------------
%% @doc Test whether an element is a member of the original set i,e. the one
%% retrieved from Riak.
%% @end
%% -----------------------------------------------------------------------------
-spec is_original_element(binary(), riakc_set:riakc_set()) -> boolean().

is_original_element(Element, #babel_set{values = V}) ->
    ordsets:is_element(Element, V).



%% =============================================================================
%% PRIVATE
%% =============================================================================



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