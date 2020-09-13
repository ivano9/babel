

# Module babel_key_value #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

A Key Value coding interface for property lists and maps.

<a name="types"></a>

## Data Types ##




### <a name="type-key">key()</a> ###


<pre><code>
key() = atom() | binary() | tuple() | <a href="riakc_map.md#type-key">riakc_map:key()</a> | <a href="#type-path">path()</a>
</code></pre>




### <a name="type-path">path()</a> ###


<pre><code>
path() = [atom() | binary() | tuple() | <a href="riakc_map.md#type-key">riakc_map:key()</a>]
</code></pre>




### <a name="type-t">t()</a> ###


<pre><code>
t() = map() | [<a href="proplists.md#type-property">proplists:property()</a>] | <a href="riakc_map.md#type-crdt_map">riakc_map:crdt_map()</a>
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#collect-2">collect/2</a></td><td></td></tr><tr><td valign="top"><a href="#collect-3">collect/3</a></td><td></td></tr><tr><td valign="top"><a href="#get-2">get/2</a></td><td>Returns value <code>Value</code> associated with <code>Key</code> if <code>KVTerm</code> contains <code>Key</code>.</td></tr><tr><td valign="top"><a href="#get-3">get/3</a></td><td></td></tr><tr><td valign="top"><a href="#set-3">set/3</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="collect-2"></a>

### collect/2 ###

<pre><code>
collect(Keys::[<a href="#type-key">key()</a>], KVTerm::<a href="#type-t">t()</a>) -&gt; [any()]
</code></pre>
<br />

<a name="collect-3"></a>

### collect/3 ###

<pre><code>
collect(Keys::[<a href="#type-key">key()</a>], KVTerm::<a href="#type-t">t()</a>, Default::any()) -&gt; [any()]
</code></pre>
<br />

<a name="get-2"></a>

### get/2 ###

<pre><code>
get(Key::<a href="#type-key">key()</a>, KVTerm::<a href="#type-t">t()</a>) -&gt; Value::term()
</code></pre>
<br />

Returns value `Value` associated with `Key` if `KVTerm` contains `Key`.
`Key` can be an atom, a binary or a path represented as a list of atoms and/
or binaries, or as a tuple of atoms and/or binaries.

The call fails with a {badarg, `KVTerm`} exception if `KVTerm` is not a
property list, map or Riak CRDT Map.
It also fails with a {badkey, `Key`} exception if no
value is associated with `Key`.

> In the case of Riak CRDT Maps a key MUST be a `riakc_map:key()`.

<a name="get-3"></a>

### get/3 ###

<pre><code>
get(Key::<a href="#type-key">key()</a>, KVTerm::<a href="#type-t">t()</a>, Default::term()) -&gt; term()
</code></pre>
<br />

<a name="set-3"></a>

### set/3 ###

<pre><code>
set(Key::<a href="#type-key">key()</a>, Value::any(), KVTerm::<a href="#type-t">t()</a>) -&gt; <a href="#type-t">t()</a>
</code></pre>
<br />
