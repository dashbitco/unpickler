defmodule Unpickler do
  @moduledoc """
  `Unpickler` is a library for loading data in the Python's
  [pickle](https://docs.python.org/3/library/pickle.html) format.

  Supports all pickle protocols from 0 to 5.
  """

  alias Unpickler.Global
  alias Unpickler.Object

  @doc ~S"""
  Loads the given pickle binary.

  Basic literals and data structures are deserialized as corresponding
  Elixir terms whenever possible. The pickle data may include arbitrary
  Python objects, so in all other cases the `Unpickler.Object` struct
  is used. This struct holds all the information that would be used for
  object reconstruction. You can define a custom `:object_resolver`
  function to recognise certain objects and map them to whatever data
  structure you see fit.

  ## Object references

  Note that if the object hierarchy includes circular references, it
  is inherently impossible to represent in Elixir. One example of such
  data structure is a list with a reference to itself:

  ```python
  x = []
  x.append(x)
  ```

  On the other hand, multiple references to the same object are restored
  as expected, without duplicating memory, as in:

  ```python
  x = [1, 2, 3]
  y = (x, x)
  ```

  ## Options

    * `:object_resolver` - a function for constructing a custom term
      corresponding to a Python object. Receives `Unpickler.Object`
      as an argument and should return the term as `{:ok, term}` or
      `:error` if not applicable

    * `:persistent_id_resolver` - a function returning an object for
      the given persistent id. This function is required if the data
      includes a persistent id, otherwise an error is raised

  ## Examples

  The scalar `1` would be loaded like so:

      iex> Unpickler.load!(<<128, 4, 75, 1, 46>>)
      {1, ""}

  Next, a more complex data structure:

  ```python
  [1, 2.0, "text", (None, True), {"key": "val"}, b"\x01\x00"]
  ```

      iex> data =
      ...>   <<128, 4, 149, 47, 0, 0, 0, 0, 0, 0, 0, 93, 148, 40, 75, 1, 71, 64, 0, 0, 0, 0, 0, 0, 0,
      ...>     140, 4, 116, 101, 120, 116, 148, 78, 136, 134, 148, 125, 148, 140, 3, 107, 101, 121,
      ...>     148, 140, 3, 118, 97, 108, 148, 115, 67, 2, 1, 0, 148, 101, 46>>
      iex> Unpickler.load!(data)
      {[1, 2.0, "text", {nil, true}, %{"key" => "val"}, <<1, 0>>], ""}

  ### Objects

  Other objects end up as `Unpickler.Object`

  ```python
  from datetime import date
  date.fromisoformat("2022-05-17")
  ```

      iex> data =
      ...>   <<128, 4, 149, 32, 0, 0, 0, 0, 0, 0, 0, 140, 8, 100, 97, 116, 101, 116, 105, 109, 101,
      ...>     148, 140, 4, 100, 97, 116, 101, 148, 147, 148, 67, 4, 7, 230, 5, 17, 148, 133, 148, 82,
      ...>     148, 46>>
      iex> Unpickler.load!(data)
      {%Unpickler.Object{
         append_items: [],
         args: [<<7, 230, 5, 17>>],
         constructor: "datetime.date",
         kwargs: %{},
         set_items: [],
         state: nil
       }, ""}

  For those, we can customize construction by specifying an `:object_resolver`

  ```python
  from datetime import date
  date.fromisoformat("2022-05-17")
  ```

      iex> data =
      ...>   <<128, 4, 149, 32, 0, 0, 0, 0, 0, 0, 0, 140, 8, 100, 97, 116, 101, 116, 105, 109, 101,
      ...>     148, 140, 4, 100, 97, 116, 101, 148, 147, 148, 67, 4, 7, 230, 5, 17, 148, 133, 148, 82,
      ...>     148, 46>>
      iex> object_resolver = fn
      ...>   # See https://github.com/python/cpython/blob/3.10/Lib/datetime.py#L1094-L1105
      ...>   %{constructor: "datetime.date", args: [<<year_hi, year_lo, month, day>>]} ->
      ...>     {:ok, date} = Date.new(year_hi * 256 + year_lo, month, day)
      ...>     {:ok, date}
      ...>
      ...>   _ ->
      ...>     :error
      ...> end
      iex> Unpickler.load!(data, object_resolver: object_resolver)
      {~D[2022-05-17], ""}

  """
  @spec load!(binary(), keyword()) :: {term(), rest :: binary()}
  def load!(binary, opts \\ []) do
    object_resolver = opts[:object_resolver]
    persistent_id_resolver = opts[:persistent_id_resolver]

    load_op(binary, %{
      stack: [],
      metastack: [],
      memo: %{},
      refs: %{},
      object_resolver: object_resolver,
      persistent_id_resolver: persistent_id_resolver
    })
  end

  @highest_protocol 5

  # Operations
  #
  # A pickle file is essentially a list of instructions for so-called
  # pickle machine (PM). Each instruction starts with a 1-byte opcode,
  # which can be followed by arguments of arbitrary size. Those
  # instructions try to replicate the original object step by step.
  #
  # To ensure compatibility, subsequent pickle protocols introduce new
  # operations, but never change or drop existing ones.
  #
  # See [1] for a detailed description of the protocol and individual
  # operations and [2] for the corresponding Python implementation.
  #
  # [1]: https://github.com/python/cpython/blob/3.11/Lib/pickletools.py
  # [2]: https://github.com/python/cpython/blob/3.11/Lib/pickle.py

  # Protocol 0 and 1

  @op_mark 40
  @op_stop 46
  @op_pop 48
  @op_pop_mark 49
  @op_dup 50
  @op_float 70
  @op_int 73
  @op_binint 74
  @op_binint1 75
  @op_long 76
  @op_binint2 77
  @op_none 78
  @op_persid 80
  @op_binpersid 81
  @op_reduce 82
  @op_string 83
  @op_binstring 84
  @op_short_binstring 85
  @op_unicode 86
  @op_binunicode 88
  @op_append 97
  @op_build 98
  @op_global 99
  @op_dict 100
  @op_empty_dict 125
  @op_appends 101
  @op_get 103
  @op_binget 104
  @op_inst 105
  @op_long_binget 106
  @op_list 108
  @op_empty_list 93
  @op_obj 111
  @op_put 112
  @op_binput 113
  @op_long_binput 114
  @op_setitem 115
  @op_tuple 116
  @op_empty_tuple 41
  @op_setitems 117
  @op_binfloat 71

  # Protocol 2

  @op_proto 128
  @op_newobj 129
  @op_ext1 130
  @op_ext2 131
  @op_ext4 132
  @op_tuple1 133
  @op_tuple2 134
  @op_tuple3 135
  @op_newtrue 136
  @op_newfalse 137
  @op_long1 138
  @op_long4 139

  # Protocol 3 (Python 3.x)

  @op_binbytes 66
  @op_short_binbytes 67

  # Protocol 4

  @op_short_binunicode 140
  @op_binunicode8 141
  @op_binbytes8 142
  @op_empty_set 143
  @op_additems 144
  @op_frozenset 145
  @op_newobj_ex 146
  @op_stack_global 147
  @op_memoize 148
  @op_frame 149

  # Protocol 5

  @op_bytearray8 150
  @op_next_buffer 151
  @op_readonly_buffer 152

  defp load_op(<<opcode, rest::binary>>, state), do: load_op(opcode, rest, state)

  # Ways to spell integers

  defp load_op(@op_int, rest, state) do
    {string, rest} = read_line(rest)

    value =
      case string do
        "01" -> true
        "00" -> false
        string -> String.to_integer(string)
      end

    state = push(state, value)
    load_op(rest, state)
  end

  defp load_op(@op_binint, rest, state) do
    <<int::integer-little-signed-size(32), rest::binary>> = rest
    state = push(state, int)
    load_op(rest, state)
  end

  defp load_op(@op_binint1, rest, state) do
    <<int, rest::binary>> = rest
    state = push(state, int)
    load_op(rest, state)
  end

  defp load_op(@op_binint2, rest, state) do
    <<int::integer-little-size(16), rest::binary>> = rest
    state = push(state, int)
    load_op(rest, state)
  end

  defp load_op(@op_long, rest, state) do
    {string, rest} = read_line(rest)
    prefix_size = byte_size(string) - 1
    <<string::binary-size(prefix_size), ?L>> = string
    int = String.to_integer(string)
    state = push(state, int)
    load_op(rest, state)
  end

  defp load_op(@op_long1, rest, state) do
    <<size, int::integer-little-signed-size(size)-unit(8), rest::binary>> = rest
    state = push(state, int)
    load_op(rest, state)
  end

  defp load_op(@op_long4, rest, state) do
    <<
      size::integer-little-signed-size(32),
      int::integer-little-signed-size(size)-unit(8),
      rest::binary
    >> = rest

    state = push(state, int)
    load_op(rest, state)
  end

  # Ways to spell strings (8-bit, not Unicode)

  defp load_op(@op_string, rest, state) do
    {string, rest} = read_line(rest)
    content_size = byte_size(string) - 2

    string =
      case string do
        <<q, string::binary-size(content_size), q>> when q in [?', ?"] ->
          Macro.unescape_string(string)
      end

    state = push(state, string)
    load_op(rest, state)
  end

  defp load_op(@op_binstring, rest, state) do
    <<size::integer-little-signed-size(32), string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  defp load_op(@op_short_binstring, rest, state) do
    <<size, string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  # Bytes (protocol 3 and higher)

  defp load_op(@op_short_binbytes, rest, state) do
    <<size, string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  defp load_op(@op_binbytes, rest, state) do
    <<size::integer-little-signed-size(32), string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  defp load_op(@op_binbytes8, rest, state) do
    <<size::integer-little-size(64), string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  # Bytearray (protocol 5 and higher)

  defp load_op(@op_bytearray8, rest, state) do
    <<size::integer-little-size(64), string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  # Out-of-band buffer (protocol 5 and higher)

  defp load_op(@op_next_buffer, _rest, _state) do
    unsupported_out_of_bound_buffers!()
  end

  defp load_op(@op_readonly_buffer, rest, state) do
    load_op(rest, state)
  end

  # Ways to spell None

  defp load_op(@op_none, rest, state) do
    state = push(state, nil)
    load_op(rest, state)
  end

  # Ways to spell bools, starting with proto 2

  defp load_op(@op_newtrue, rest, state) do
    state = push(state, true)
    load_op(rest, state)
  end

  defp load_op(@op_newfalse, rest, state) do
    state = push(state, false)
    load_op(rest, state)
  end

  # Ways to spell Unicode strings

  defp load_op(@op_unicode, rest, state) do
    # Note that Python encodes the string using raw-unicode-escape,
    # so that it fits into ASCII, however this opcode is obsolete,
    # so we keep it as is as our best effort
    {string, rest} = read_line(rest)
    state = push(state, string)
    load_op(rest, state)
  end

  defp load_op(@op_short_binunicode, rest, state) do
    <<size, string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  defp load_op(@op_binunicode, rest, state) do
    <<size::integer-little-size(32), string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  defp load_op(@op_binunicode8, rest, state) do
    <<size::integer-little-size(64), string::binary-size(size), rest::binary>> = rest
    state = push(state, string)
    load_op(rest, state)
  end

  # Ways to spell floats

  defp load_op(@op_float, rest, state) do
    {string, rest} = read_line(rest)
    float = String.to_float(string)
    state = push(state, float)
    load_op(rest, state)
  end

  defp load_op(@op_binfloat, rest, state) do
    <<float::float-big-size(64), rest::binary>> = rest
    state = push(state, float)
    load_op(rest, state)
  end

  # Ways to build lists

  defp load_op(@op_empty_list, rest, state) do
    state = push(state, [])
    load_op(rest, state)
  end

  defp load_op(@op_append, rest, state) do
    {item, state} = pop(state)

    state =
      update_head(state, fn
        list when is_list(list) -> list ++ [item]
        %Object{} = object -> Object.append_many(object, [item])
      end)

    load_op(rest, state)
  end

  defp load_op(@op_appends, rest, state) do
    {items, state} = pop_mark(state)
    elems = Enum.reverse(items)

    state =
      update_head(state, fn
        list when is_list(list) -> list ++ elems
        %Object{} = object -> Object.append_many(object, elems)
      end)

    load_op(rest, state)
  end

  defp load_op(@op_list, rest, state) do
    {items, state} = pop_mark(state)
    list = Enum.reverse(items)
    state = push(state, list)
    load_op(rest, state)
  end

  # Ways to build tuples

  defp load_op(@op_empty_tuple, rest, state) do
    state = push(state, {})
    load_op(rest, state)
  end

  defp load_op(@op_tuple, rest, state) do
    {items, state} = pop_mark(state)
    tuple = items |> Enum.reverse() |> List.to_tuple()
    state = push(state, tuple)
    load_op(rest, state)
  end

  defp load_op(@op_tuple1, rest, state) do
    {elem, state} = pop(state)
    state = push(state, {elem})
    load_op(rest, state)
  end

  defp load_op(@op_tuple2, rest, state) do
    {[elem2, elem1], state} = pop_many(state, 2)
    state = push(state, {elem1, elem2})
    load_op(rest, state)
  end

  defp load_op(@op_tuple3, rest, state) do
    {[elem3, elem2, elem1], state} = pop_many(state, 3)
    state = push(state, {elem1, elem2, elem3})
    load_op(rest, state)
  end

  # Ways to build dicts

  defp load_op(@op_empty_dict, rest, state) do
    state = push(state, %{})
    load_op(rest, state)
  end

  defp load_op(@op_dict, rest, state) do
    {items, state} = pop_mark(state)
    map = items |> stack_items_to_pairs() |> Map.new()
    state = push(state, map)
    load_op(rest, state)
  end

  defp load_op(@op_setitem, rest, state) do
    {[val, key], state} = pop_many(state, 2)

    state =
      update_head(state, fn
        %Object{} = object -> Object.set_many(object, [{key, val}])
        %{} = map -> Map.put(map, key, val)
      end)

    load_op(rest, state)
  end

  defp load_op(@op_setitems, rest, state) do
    {items, state} = pop_mark(state)

    pairs = stack_items_to_pairs(items)

    state =
      update_head(state, fn
        %Object{} = object -> Object.set_many(object, pairs)
        %{} = map -> Enum.into(pairs, map)
      end)

    load_op(rest, state)
  end

  # Ways to build sets

  defp load_op(@op_empty_set, rest, state) do
    state = push(state, MapSet.new())
    load_op(rest, state)
  end

  defp load_op(@op_additems, rest, state) do
    {items, state} = pop_mark(state)
    state = update_head(state, fn set -> Enum.into(items, set) end)
    load_op(rest, state)
  end

  # Way to build frozensets

  defp load_op(@op_frozenset, rest, state) do
    {items, state} = pop_mark(state)
    set = MapSet.new(items)
    state = push(state, set)
    load_op(rest, state)
  end

  # Stack manipulation

  defp load_op(@op_pop, rest, state) do
    {_item, state} = pop(state)
    load_op(rest, state)
  end

  defp load_op(@op_dup, rest, state) do
    state = update_in(state.stack, fn [item | stack] -> [item, item | stack] end)
    load_op(rest, state)
  end

  defp load_op(@op_mark, rest, state) do
    state = push_mark(state)
    load_op(rest, state)
  end

  defp load_op(@op_pop_mark, rest, state) do
    {_items, state} = pop_mark(state)
    load_op(rest, state)
  end

  # Memo manipulation

  defp load_op(@op_get, rest, state) do
    {string, rest} = read_line(rest)
    idx = String.to_integer(string)
    state = push_from_memo(state, idx)
    load_op(rest, state)
  end

  defp load_op(@op_binget, rest, state) do
    <<idx, rest::binary>> = rest
    state = push_from_memo(state, idx)
    load_op(rest, state)
  end

  defp load_op(@op_long_binget, rest, state) do
    <<idx::integer-little-size(32), rest::binary>> = rest
    state = push_from_memo(state, idx)
    load_op(rest, state)
  end

  defp load_op(@op_put, rest, state) do
    {string, rest} = read_line(rest)
    idx = String.to_integer(string)
    state = memoize(state, idx)
    load_op(rest, state)
  end

  defp load_op(@op_binput, rest, state) do
    <<idx, rest::binary>> = rest
    state = memoize(state, idx)
    load_op(rest, state)
  end

  defp load_op(@op_long_binput, rest, state) do
    <<idx::integer-little-size(32), rest::binary>> = rest
    state = memoize(state, idx)
    load_op(rest, state)
  end

  defp load_op(@op_memoize, rest, state) do
    idx = map_size(state.memo)
    state = memoize(state, idx)
    load_op(rest, state)
  end

  # Access the extension registry (predefined objects)

  defp load_op(@op_ext1, _rest, _state) do
    unsupported_extension_registry!()
  end

  defp load_op(@op_ext2, _rest, _state) do
    unsupported_extension_registry!()
  end

  defp load_op(@op_ext4, _rest, _state) do
    unsupported_extension_registry!()
  end

  # Push a class or function reference onto the stack

  defp load_op(@op_global, rest, state) do
    {module, rest} = read_line(rest)
    {name, rest} = read_line(rest)
    global = Global.new(module, name)
    state = push(state, global)
    load_op(rest, state)
  end

  defp load_op(@op_stack_global, rest, state) do
    {[name, module], state} = pop_many(state, 2)
    global = Global.new(module, name)
    state = push(state, global)
    load_op(rest, state)
  end

  # Ways to build objects of classes pickle doesn't know about

  defp load_op(@op_reduce, rest, state) do
    {[args_tuple, callable], state} = pop_many(state, 2)
    args = Tuple.to_list(args_tuple)
    object = Object.new(callable, args, %{})
    state = push(state, object)
    load_op(rest, state)
  end

  defp load_op(@op_build, rest, state) do
    {object_state, state} = pop(state)

    state =
      update_head(state, fn %Object{} = object ->
        Object.set_state(object, object_state)
      end)

    load_op(rest, state)
  end

  defp load_op(@op_inst, rest, state) do
    {module, rest} = read_line(rest)
    {name, rest} = read_line(rest)
    {items, state} = pop_mark(state)
    args = Enum.reverse(items)
    class = Global.new(module, name)
    object = Object.new(class, args, %{})
    state = push(state, object)
    load_op(rest, state)
  end

  defp load_op(@op_obj, rest, state) do
    {items, state} = pop_mark(state)
    [class | args] = Enum.reverse(items)
    object = Object.new(class, args, %{})
    state = push(state, object)
    load_op(rest, state)
  end

  defp load_op(@op_newobj, rest, state) do
    {[args_tuple, class], state} = pop_many(state, 2)
    args = Tuple.to_list(args_tuple)
    new_method = Global.new(class, "__new__")
    object = Object.new(new_method, [class | args], %{})
    state = push(state, object)
    load_op(rest, state)
  end

  defp load_op(@op_newobj_ex, rest, state) do
    {[kwargs, args_tuple, class], state} = pop_many(state, 3)
    args = Tuple.to_list(args_tuple)
    new_method = Global.new(class, "__new__")
    object = Object.new(new_method, [class | args], kwargs)
    state = push(state, object)
    load_op(rest, state)
  end

  # Machine control

  defp load_op(@op_proto, rest, state) do
    <<proto, rest::binary>> = rest

    if proto > @highest_protocol do
      raise "unsupported pickle protocol: #{proto}"
    end

    load_op(rest, state)
  end

  defp load_op(@op_stop, rest, state) do
    {item, %{stack: []}} = pop(state)
    {item, rest}
  end

  # Framing support

  defp load_op(@op_frame, rest, state) do
    <<_size::integer-little-size(64), rest::binary>> = rest
    # Since we work on an in-memory data, framing is not applicable
    load_op(rest, state)
  end

  # Ways to deal with persistent ids

  defp load_op(@op_persid, rest, state) do
    {id, rest} = read_line(rest)
    value = load_persistent_id(state, id)
    state = push(state, value)
    load_op(rest, state)
  end

  defp load_op(@op_binpersid, rest, state) do
    {id, state} = pop(state)
    value = load_persistent_id(state, id)
    state = push(state, value)
    load_op(rest, state)
  end

  defp push(%{stack: stack} = state, item) do
    %{state | stack: [item | stack]}
  end

  defp pop(%{stack: [item | stack]} = state) do
    state = %{state | stack: stack}
    {[item], state} = finalize_stack_items(state, [item])
    {item, state}
  end

  defp pop_many(state, count) do
    {items, stack} = Enum.split(state.stack, count)
    state = %{state | stack: stack}
    finalize_stack_items(state, items)
  end

  defp update_head(%{stack: [ref | _]} = state, fun) when is_reference(ref) do
    update_in(state.refs[ref], fun)
  end

  defp update_head(%{stack: [item | stack]} = state, fun) do
    %{state | stack: [fun.(item) | stack]}
  end

  defp push_mark(%{stack: stack, metastack: metastack} = state) do
    %{state | stack: [], metastack: [stack | metastack]}
  end

  defp pop_mark(%{stack: stack, metastack: [prev_stack | metastack]} = state) do
    state = %{state | stack: prev_stack, metastack: metastack}
    finalize_stack_items(state, stack)
  end

  defp memoize(%{stack: [item | stack]} = state, idx) do
    # We memoize an object from the stack, however subsequent operations
    # can modify that object on the stack. In Python the memo only holds
    # a reference to that object and mutability ensures it stays in sync.
    # To achieve a similar behaviour, whenever an object is memoized we
    # replace it with a random reference, both on the stack and in the
    # memo, and we keep the referenced object in a single place

    ref = make_ref()
    state = put_in(state.refs[ref], item)
    state = put_in(state.memo[idx], ref)
    %{state | stack: [ref | stack]}
  end

  defp push_from_memo(state, idx) do
    item = state.memo[idx]
    push(state, item)
  end

  defp finalize_stack_items(state, items) do
    # When a Unpickler.Object is removed from the stack, it should
    # include all the relevant information, so we try resolving it
    # to a more specific term. Also, we replace object references
    # with the actual values

    Enum.map_reduce(items, state, fn
      ref, state when is_reference(ref) ->
        state = update_in(state.refs[ref], &resolve_object(&1, state))
        {state.refs[ref], state}

      item, state ->
        {resolve_object(item, state), state}
    end)
  end

  defp resolve_object(%Object{} = object, state) do
    with :error <- built_in_resolver(object),
         :error <- if(state.object_resolver, do: state.object_resolver.(object), else: :error) do
      object
    else
      {:ok, value} ->
        value

      other ->
        raise "expected object resolver to return {:ok, term} or :error, got: #{inspect(other)}"
    end
  end

  defp resolve_object(item, _state), do: item

  defp built_in_resolver(%{constructor: "builtins.getattr", args: [%Global{} = global, name]}) do
    {:ok, Global.new(global, name)}
  end

  defp built_in_resolver(%{constructor: "builtins.bytearray", args: args}) do
    case args do
      [] -> {:ok, <<>>}
      [binary] -> {:ok, binary}
    end
  end

  defp built_in_resolver(_), do: :error

  defp read_line(binary) do
    [line, rest] = :binary.split(binary, "\n")
    {line, rest}
  end

  defp stack_items_to_pairs(items) do
    items
    |> Enum.chunk_every(2)
    |> Enum.reverse()
    |> Enum.map(fn [val, key] -> {key, val} end)
  end

  defp load_persistent_id(state, id) do
    if resolver = state.persistent_id_resolver do
      resolver.(id)
    else
      raise "encountered persistent id: #{inspect(id)}, but no resolver was specified. " <>
              "Make sure to pass the :persistent_id_resolver option"
    end
  end

  defp unsupported_out_of_bound_buffers!() do
    # The out-of-band buffer mechanism is designed primarily for cases
    # where the pickle stream is sent between Python processes, rather
    # than persisted to a file, and it aims to to reduce memory copies.
    #
    # We focus on mere deserialization, so this feature is not relevant
    # for our implementation.
    #
    # [1]: https://peps.python.org/pep-0574

    raise "out-of-band buffers are not supported"
  end

  defp unsupported_extension_registry!() do
    # The extension registry is a mechanism for reducing the pickle
    # size by replacing common (<module>, <name>) refernces with a
    # single numerical code. An extension defines such mapping, but
    # since pickles are meant to be context-free, this doesn't seem
    # to be used in practice.
    #
    # If there is ever a set of standardized extensions we can handle
    # those and also support an option for user-defined extensions.
    #
    # [1]: https://peps.python.org/pep-0307/#the-extension-registry
    # [2]: https://github.com/python/cpython/blob/3.11/Lib/copyreg.py#L164-L171

    raise "pickle extension registry is not supported"
  end
end
