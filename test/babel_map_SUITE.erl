-module(babel_map_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-compile(export_all).
-compile([nowarn_export_all, export_all]).


all() ->
    [
        create_test,
        create_test_2,
        put_1_test,
        put_2_test,
        to_riak_op_test,
        babel_put_test,
        babel_get_test,
        update_1_test,
        update_2_test,
        update_3_test,
        update_4_test,
        update_5_test,
        update_6_test,
        update_7_test,
        patch_1_test,
        patch_2_test,
        patch_3_test,
        undefined_test_1,
        set_test_1,
        set_undefined_test_1,
        set_undefined_test_2
    ].



init_per_suite(Config) ->
    ok = common:setup(),
    meck:unload(),
    Config.

end_per_suite(Config) ->
    meck:unload(),
    {save_config, Config}.


create_test(_) ->
    M = babel_map:new(data(), spec()),
    ?assertEqual(true, babel_map:is_type(M)).

create_test_2(_) ->
    M = babel_map:new(data1(), spec()),
    ?assertEqual(true, babel_map:is_type(M)).


to_riak_op_test(_) ->
    M = babel_map:new(data(), spec()),
    Op = babel_map:to_riak_op(M, spec()),
    ?assertEqual(true, is_tuple(Op)).


put_1_test(_) ->
    M0 = babel_map:new(),
    M1 = babel_map:put(<<"a">>, 1, M0),
    ?assertEqual(1, babel_map:get_value(<<"a">>, M1)).


put_2_test(_) ->
    M0 = babel_map:new(),
    M1 = babel_map:put(<<"a">>, babel_map:new(), M0),
    M2 = babel_map:put([<<"a">>, <<"aa">>], 1, M1),
    ?assertEqual(1, babel_map:get_value([<<"a">>, <<"aa">>], M2)),
    ?assertEqual(1, maps:get(<<"aa">>, babel_map:get_value(<<"a">>, M2))),

    M3 = babel_map:put([<<"a">>, <<"ab">>, <<"aba">>], 1, M2),
    ?assertEqual(
        1,
        babel_map:get_value([<<"a">>, <<"ab">>, <<"aba">>], M3)
    ),
    ?assertEqual(
        1,
        maps:get(
            <<"aba">>,
            maps:get(<<"ab">>, babel_map:get_value(<<"a">>, M3))
        )
    ).


babel_put_test(_) ->
    M0 = babel_map:new(data(), spec()),
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),

    Opts = #{
        connection => Conn,
        riak_opts => #{return_body => true}
    },

    ?assertEqual(false, reliable:is_in_workflow()),

    {ok, M1} = babel:put(
        {<<"index_data">>, <<"test">>},<<"to_riak_op_test">>, M0, spec(), Opts
    ),
    ?assertEqual(babel_map:value(M0), babel_map:value(M1)).


babel_get_test(_) ->
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    pong = riakc_pb_socket:ping(Conn),
    {ok, M} = babel:get(
        {<<"index_data">>, <<"test">>},
        <<"to_riak_op_test">>,
        spec(),
        #{connection => Conn}
    ),
    ?assertEqual(true, babel_map:is_type(M)).

modify_test(_) ->
    Spec = #{<<"foo">> => {map, #{'_' => {register, integer}}}},
    M0 = babel_map:new(#{<<"foo">> => #{<<"bar">> => 1}}, Spec, <<>>),
    M1 = babel_map:set(<<"foo">>, babel_map:new(#{}), M0),
    ?assertNotEqual(
        undefined,
        babel_map:to_riak_op(M1, Spec)
    ).



update_1_test(_) ->
    T1 = babel_map:new(data1(), spec()),
    T2 = babel_map:update(data2(), T1, spec()),
    ?assertEqual(
        <<"11111111">>, babel_map:get_value(<<"identification_number">>, T2)
    ),
    ?assertEqual(
        <<"11111111">>, babel_map:get_value(<<"identification_number">>, T2)
    ),
    ?assertEqual(
        [a, b, c],
        babel_map:get_value(<<"set_prop">>, T2)
    ),
    ?assertEqual(
        100,
        babel_map:get_value(<<"counter_prop">>, T2)
    ),
    ?assertEqual(
        true,
        babel_map:get_value(<<"flag_prop">>, T2)
    ).

update_2_test(_) ->
    T1 = babel_map:new(data1(), spec()),

    T2 = babel_map:update(
        #{<<"identification_number">> => undefined}, T1,  spec()
    ),
    ?assertEqual(
        <<"874920948">>, babel_map:get_value(<<"identification_number">>, T2)
    ).

update_3_test(_) ->
    Ctxt = <<>>,
    T1 = babel_map:new(data1(), spec(), Ctxt),

    T2 = babel_map:update(
        #{<<"identification_number">> => undefined}, T1,  spec()
    ),
    ?assertEqual(
        undefined,
        babel_map:get_value(<<"identification_number">>, T2, undefined)
    ).

update_4_test(_) ->
    Spec = #{
        <<"mapping">> => {map, #{'_' => {register, binary}}}
    },
    Data = #{
        <<"mapping">> => #{
            <<"key1">> => <<"value1">>,
            <<"key2">> => <<"value2">>
        }
    },
    Map = babel_map:update(Data, babel_map:new(), Spec),
    ?assertEqual(
        Data,
        babel_map:value(Map)
    ).


update_5_test(_) ->
    Spec = #{
        <<"mapping">> => {map, #{
            <<"foo">> => {map, #{'_' => {register, binary}}}
        }}
    },
    Data = #{
        <<"mapping">> => #{
            <<"foo">> => #{
                <<"key1">> => <<"value1">>,
                <<"key2">> => <<"value2">>,
                <<"key3">> => 100
            }
        }
    },
    ?assertError(
        {badkeytype, 100, {register, binary}},
        babel_map:update(Data, babel_map:new(), Spec)
    ).


update_6_test(_) ->
    Spec = #{
        <<"mapping">> => {map, #{
            <<"foo">> => {map, #{'_' => {register, binary}}}
        }}
    },
    Data = #{
        <<"mapping">> => #{
            <<"foo">> => #{
                <<"key1">> => <<"value1">>,
                <<"key2">> => <<"value2">>
            }
        }
    },
    Map = babel_map:update(Data, babel_map:new(), Spec),
    ?assertEqual(
        Data,
        babel_map:value(Map)
    ).


update_7_test(_) ->
    Spec = #{'_' => {map, #{'_' => {register, integer}}}},
    M0 = babel_map:new(#{<<"a">> => #{<<"a1">> => 1}}, Spec),
    Update0 = #{
        <<"a">> => #{<<"a2">> => 2},
        <<"b">> => #{<<"b1">> => 1}
    },
    Expected0 = #{
        <<"a">> => #{<<"a1">> => 1, <<"a2">> => 2},
        <<"b">> => #{<<"b1">> => 1}
    },
    M1 = babel_map:update(Update0, M0, Spec),
    ?assertEqual(Expected0, babel_map:value(M1)),

    Update1 = #{
        <<"a">> => #{<<"a2">> => 20},
        <<"b">> => #{<<"b1">> => 10}
    },
    Expected1 = #{
        <<"a">> => #{<<"a1">> => 1, <<"a2">> => 20},
        <<"b">> => #{<<"b1">> => 10}
    },
    M2 = babel_map:update(Update1, M1, Spec),
    ?assertEqual(Expected1, babel_map:value(M2)).


patch_1_test(_) ->
    Ctxt = <<>>,
    T1 = babel_map:new(data2(), spec(), Ctxt),

    T2 = babel_map:patch(
        [
            #{
                <<"path">> => <<"/identification_number">>,
                <<"action">> => <<"update">>,
                <<"value">> => <<"111111111">>
            },
            #{
                <<"path">> => <<"/address/postal_code">>,
                <<"action">> => <<"update">>,
                <<"value">> => <<"SW12 2XX">>
            },
            #{
                <<"path">> => <<"/set_prop">>,
                <<"action">> => <<"add_element">>,
                <<"value">> => d
            },
            #{
                <<"path">> => <<"/set_prop">>,
                <<"action">> => <<"del_element">>,
                <<"value">> => a
            },
            #{
                <<"path">> => <<"/counter_prop">>,
                <<"action">> => <<"increment">>
            },
            #{
                <<"path">> => <<"/flag_prop">>,
                <<"action">> => <<"disable">>
            }
        ],
        T1,
        spec()
    ),
    ?assertEqual(
        <<"111111111">>,
        babel_map:get_value(<<"identification_number">>, T2)
    ),
    ?assertEqual(
        <<"SW12 2XX">>,
        babel_map:get_value([<<"address">>, <<"postal_code">>], T2)
    ),
    ?assertEqual(
        [b, c, d],
        babel_map:get_value(<<"set_prop">>, T2)
    ),
    ?assertEqual(
        101,
        babel_map:get_value(<<"counter_prop">>, T2)
    ),
    ?assertEqual(
        false,
        babel_map:get_value(<<"flag_prop">>, T2)
    ),
    {Updates, Removes} = babel_map:changed_key_paths(T2),
    ?assertEqual(
        {
            lists:usort([
                [<<"account_type">>],
                [<<"active">>],
                [<<"address">>, <<"address_line1">>],
                [<<"address">>, <<"address_line2">>],
                [<<"address">>, <<"city">>],
                [<<"address">>, <<"country">>],
                [<<"address">>, <<"postal_code">>],
                [<<"address">>, <<"state">>],
                [<<"counter_prop">>],
                [<<"country_id">>],
                [<<"flag_prop">>],
                [<<"id">>],
                [<<"identification_number">>],
                [<<"identification_type">>],
                [<<"name">>],
                [<<"number">>],
                [<<"operation_mode">>],
                [<<"set_prop">>],
                [<<"version">>]
            ]),
            []
        },
        {lists:usort(Updates), Removes}
    ).


patch_2_test(_) ->
    ok.


patch_3_test(_) ->
    ok.


undefined_test_1(_) ->
    TypeSpec = #{<<"a">> => {register, binary}},
    T1 = babel_map:new(#{<<"a">> => undefined}, TypeSpec),
    ?assertEqual([], babel_map:keys(T1)).

set_test_1(_) ->
    TCSpec = #{
        <<"accepted_by">> => {register, binary},
        <<"acceptance_timestamp">> => {register, integer}
    },
    Spec = #{
        <<"version">> => {register, binary},
        <<"id">> => {register, binary},
        <<"name">> => {register, binary},
        <<"active">> => {register, boolean},
        <<"account_type">> => {register, binary},
        <<"operation_mode">> => {register, binary},
        <<"country_id">> => {register, binary},
        <<"number">> => {register, binary},
        <<"identification_type">> => {register, binary},
        <<"identification_number">> => {register, binary},
        <<"logo">> => {register, binary},
        <<"url">> => {register, binary},
        <<"address">> => {map, #{
            <<"address_line1">> => {register, binary},
            <<"address_line2">> => {register, binary},
            <<"city">> => {register, binary},
            <<"state">> => {register, binary},
            <<"country">> => {register, binary},
            <<"postal_code">> => {register, binary}
        }},
        <<"services">> => {map, #{'_' => {map, #{
            <<"description">> => {register, binary},
            <<"expiry_date">> => {register, binary},
            <<"enabled">> => {register, boolean}
        }}}},
        <<"terms_and_conditions">> => {map, #{'_' => {map, TCSpec}}},
        <<"created_by">> => {register, binary},
        <<"last_modified_by">> => {register, binary},
        <<"created_timestamp">> => {register, integer},
        <<"last_modified_timestamp">> => {register, integer}
    },
    Key = <<"terms_and_conditions">>,
    TCs = babel_map:new(
        #{
            <<"accepted_by">> => <<"user@foo.com">>,
            <<"acceptance_timestamp">> => erlang:system_time(millisecond)
        },
        TCSpec
    ),
    Version = <<"20201118">>,
    Map0 = {babel_map,#{
        <<"account_type">> => <<"business">>,<<"active">> => true,
        <<"address">> =>
            {babel_map,#{<<"address_line1">> => <<"523">>,
                        <<"city">> => <<"La Plata">>,
                        <<"country">> => <<"Argentina">>,
                        <<"postal_code">> => <<"1900">>,
                        <<"state">> => <<"Buenos Aires">>},
                    [],[],undefined},
        <<"country_id">> => <<"AR">>,
        <<"created_by">> => <<"testaccount@test.com.ar">>,
        <<"created_timestamp">> => 1605695133613,
        <<"id">> =>
            <<"mrn:account:business:22ea8fbe-f5a6-48e7-b439-20cfef4bc979">>,
        <<"identification_number">> => <<"33333333">>,
        <<"identification_type">> => <<"DNI">>,
        <<"last_modified_by">> => <<"testaccount@test.com.ar">>,
        <<"last_modified_timestamp">> => 1605695133613,
        <<"name">> => <<"My Account Ale Sin Phones and Emails">>,
        <<"number">> => <<"AB1234567">>,
        <<"operation_mode">> => <<"normal">>,
        <<"services">> =>
            {babel_map,#{<<"mrn:service:fleet">> =>
                            {babel_map,#{<<"description">> => <<"Plan fleet habilitado">>,
                                        <<"enabled">> => true,
                                        <<"expiry_date">> => <<"2017-05-12T00:00:00+00:00">>},
                                        [],[],undefined}},
                    [],[],undefined},
        <<"version">> => <<"1.0">>},
        [],[],
        <<>>
    },
    Map1 = babel_map:set([Key, Version], TCs, Map0),
    ?assertEqual(
        babel_map:value(TCs),
        babel_map:value(babel_map:get([Key, Version], Map1))
    ),
    {ok, Conn} = riakc_pb_socket:start_link("127.0.0.1", 8087),
    ?assertEqual(pong, riakc_pb_socket:ping(Conn)),

    ok = babel:put(
        {<<"index_data">>, <<"test">>},
        <<"set_test_1">>,
        %% We revert context to undefine so that Riak does not fail
        babel_map:set_context(undefined, Map1),
        Spec,
        #{connection => Conn}
    ),
    ok.


set_undefined_test_1(_) ->
    T1 = babel_map:new(#{<<"a">> => 1}, #{<<"a">> => {register, integer}}),
    %% No context, so nop
    T2 = babel_map:set(<<"a">>, undefined, T1),
    ?assertEqual([<<"a">>], babel_map:keys(T2)).


set_undefined_test_2(_) ->
    Ctxt = <<>>,
    T1 = babel_map:new(
        #{<<"a">> => 1}, #{<<"a">> => {register, integer}}, Ctxt
    ),
    T2 = babel_map:set(<<"a">>, undefined, T1),
    ?assertEqual([], babel_map:keys(T2)).



%% =============================================================================
%% RESOURCES
%% =============================================================================




data() ->
    #{
        <<"version">> => <<"2.0">>,
        <<"id">> => <<"mrn:business_account:1">>,
        <<"account_type">> => <<"business">>,
        <<"name">> => <<"Leapsight">>,
        <<"active">> => true,
        <<"operation_mode">> => <<"normal">>,
        <<"country_id">> => <<"AR">>,
        <<"number">> => <<"AC897698769">>,
        <<"identification_type">> => <<"PASSPORT">>,
        <<"identification_number">> => <<"874920948">>,
        <<"address">> => #{
            <<"address_line1">> => <<"Clement Street">>,
            <<"address_line2">> => <<"Floor 8 Room B">>,
            <<"city">> => <<"London">>,
            <<"state">> => <<"London">>,
            <<"country">> => <<"United Kingdom">>,
            <<"postal_code">> => <<"SW12 2RT">>
        },
        %% decode #{Email => Tag} --> [{email => Email, tag => Tag}]
        %% encode [{number => Email, tag => Tag}] --> #{Email => Tag}
        %% <<"emails">> => [
        %%     #{
        %%         <<"email">> =><<"john.doe@foo.com">>,
        %%         <<"tage">> => <<"work">>
        %%     }
        %% ],
        <<"emails">> => #{
            <<"john.doe@foo.com">> => <<"work">>
        },
        %% <<"phones">> =>  [
        %%     #{
        %%         <<"number">> => <<"09823092834">>,
        %%         <<"tage">> => <<"work">>
        %%     }
        %% ],
        <<"phones">> => #{
            <<"09823092834">> => <<"work">>
        },
        <<"services">> => #{
            <<"mrn:service:vehicle_lite">> => #{
                <<"enabled">> => true,
                <<"description">> => <<"Baz Service">>,
                <<"expiry_date">> => <<"2020/10/09">>
            }
        },
        <<"created_by">> => <<"mrn:user:1">>,
        <<"last_modified_by">> => <<"mrn:user:1">>,
        <<"created_timestamp">> => 1599835691640,
        <<"last_modified_timestamp">> => 1599835691640
    }.


data1() ->
    #{
        <<"version">> => <<"2.0">>,
        <<"id">> => <<"mrn:business_account:1">>,
        <<"account_type">> => <<"business">>,
        <<"name">> => <<"Leapsight">>,
        <<"active">> => true,
        <<"operation_mode">> => <<"normal">>,
        <<"country_id">> => <<"AR">>,
        <<"number">> => <<"AC897698769">>,
        <<"identification_type">> => <<"PASSPORT">>,
        <<"identification_number">> => <<"874920948">>,
        <<"address">> => #{
            <<"address_line1">> => <<"Clement Street">>,
            <<"address_line2">> => <<"Floor 8 Room B">>,
            <<"city">> => <<"London">>,
            <<"state">> => <<"London">>,
            <<"country">> => <<"United Kingdom">>,
            <<"postal_code">> => <<"SW12 2RT">>
        }
    }.


data2() ->
    #{
        <<"version">> => <<"2.0">>,
        <<"id">> => <<"mrn:business_account:1">>,
        <<"account_type">> => <<"business">>,
        <<"name">> => <<"Leapsight">>,
        <<"active">> => false,
        <<"operation_mode">> => <<"normal">>,
        <<"country_id">> => <<"UK">>,
        <<"number">> => <<"AC897698769">>,
        <<"identification_type">> => <<"PASSPORT">>,
        <<"identification_number">> => <<"11111111">>,
        <<"address">> => #{
            <<"address_line1">> => <<"Clement Street">>,
            <<"address_line2">> => <<"Floor 8 Room B">>,
            <<"city">> => <<"London">>,
            <<"state">> => <<"London">>,
            <<"country">> => <<"United Kingdom">>,
            <<"postal_code">> => <<"SW12 2RT">>
        },
        <<"set_prop">> => [a, b, c],
        <<"counter_prop">> => 100,
        <<"flag_prop">> => true
    }.


spec() ->
    #{
        <<"version">> => {register, binary},
        <<"id">> => {register, binary},
        <<"account_type">> => {register, binary},
        <<"name">> => {register, binary},
        <<"active">> => {register, boolean},
        <<"operation_mode">> => {register, binary},
        <<"country_id">> => {register, binary},
        <<"number">> => {register, binary},
        <<"identification_type">> => {register, binary},
        <<"identification_number">> => {register, binary},
        <<"address">> => {map, #{
            <<"address_line1">> => {register, binary},
            <<"address_line2">> => {register, binary},
            <<"city">> => {register, binary},
            <<"state">> => {register, binary},
            <<"country">> => {register, binary},
            <<"postal_code">> => {register, binary}
        }},
        %% emails and phones are stored as maps of their values to their tag
        %% value e.g. #{<<"john.doe@example.com">> => <<"work">>}
        %% {register, binary} means "every key in the phones | emails map has
        %% a register associated and we keep the value of the registry as a
        %% binary
        <<"emails">> => {map, #{'_' => {register, binary}}},
        <<"phones">> => {map, #{'_' => {register, binary}}},
        %% services is a mapping of serviceID to service objects
        %% e.g. #{<<"mrn:service:1">> => #{<<"description">> => ...}
        %% {map, #{..}} means "every key in the services map has a map
        %% associated with it which is always of the same type, in this case a
        %% map with 3 properties: description, expired_data and enabled"
        <<"services">> => {map, #{'_' => {map, #{
            <<"description">> => {register, binary},
            <<"expiry_date">> => {register, binary},
            <<"enabled">> => {register, boolean}
        }}}},
        <<"created_by">> => {register, binary},
        <<"last_modified_by">> => {register, binary},
        <<"created_timestamp">> => {register, integer},
        <<"last_modified_timestamp">> => {register, integer},
        <<"set_prop">> => {set, atom},
        <<"counter_prop">> => {counter, integer},
        <<"flag_prop">> => {flag, boolean}
    }.