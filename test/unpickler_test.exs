defmodule UnpicklerTest do
  use ExUnit.Case

  doctest Unpickler

  test "integer" do
    # 1-byte
    data = <<128, 4, 75, 1, 46>>
    assert Unpickler.load!(data) == {1, ""}

    # 2-byte
    data = <<128, 4, 149, 4, 0, 0, 0, 0, 0, 0, 0, 77, 232, 3, 46>>
    assert Unpickler.load!(data) == {1000, ""}

    # 4-byte
    data = <<128, 4, 149, 6, 0, 0, 0, 0, 0, 0, 0, 74, 160, 134, 1, 0, 46>>
    assert Unpickler.load!(data) == {100_000, ""}

    data = <<128, 4, 149, 6, 0, 0, 0, 0, 0, 0, 0, 74, 255, 255, 255, 255, 46>>
    assert Unpickler.load!(data) == {-1, ""}

    # 1-byte-sized
    data = <<128, 4, 149, 8, 0, 0, 0, 0, 0, 0, 0, 138, 5, 0, 228, 11, 84, 2, 46>>
    assert Unpickler.load!(data) == {10_000_000_000, ""}

    data = <<128, 4, 149, 8, 0, 0, 0, 0, 0, 0, 0, 138, 5, 0, 28, 244, 171, 253, 46>>
    assert Unpickler.load!(data) == {-10_000_000_000, ""}
  end

  test "float" do
    data = <<128, 4, 149, 10, 0, 0, 0, 0, 0, 0, 0, 71, 63, 240, 0, 0, 0, 0, 0, 0, 46>>
    assert Unpickler.load!(data) == {1.0, ""}

    data = <<128, 4, 149, 10, 0, 0, 0, 0, 0, 0, 0, 71, 191, 240, 0, 0, 0, 0, 0, 0, 46>>
    assert Unpickler.load!(data) == {-1.0, ""}
  end

  test "bool" do
    data = <<128, 4, 136, 46>>
    assert Unpickler.load!(data) == {true, ""}

    data = <<128, 4, 137, 46>>
    assert Unpickler.load!(data) == {false, ""}
  end

  test "list" do
    data = <<128, 4, 93, 148, 46>>
    assert Unpickler.load!(data) == {[], ""}

    data = <<128, 4, 149, 9, 0, 0, 0, 0, 0, 0, 0, 93, 148, 40, 75, 1, 75, 2, 101, 46>>
    assert Unpickler.load!(data) == {[1, 2], ""}
  end

  test "tuple" do
    data = <<128, 4, 41, 46>>
    assert Unpickler.load!(data) == {{}, ""}

    data = <<128, 4, 149, 5, 0, 0, 0, 0, 0, 0, 0, 75, 1, 133, 148, 46>>
    assert Unpickler.load!(data) == {{1}, ""}

    data = <<128, 4, 149, 7, 0, 0, 0, 0, 0, 0, 0, 75, 1, 75, 2, 134, 148, 46>>
    assert Unpickler.load!(data) == {{1, 2}, ""}

    data = <<128, 4, 149, 9, 0, 0, 0, 0, 0, 0, 0, 75, 1, 75, 2, 75, 3, 135, 148, 46>>
    assert Unpickler.load!(data) == {{1, 2, 3}, ""}

    data = <<128, 4, 149, 12, 0, 0, 0, 0, 0, 0, 0, 40, 75, 1, 75, 2, 75, 3, 75, 4, 116, 148, 46>>
    assert Unpickler.load!(data) == {{1, 2, 3, 4}, ""}
  end

  test "dict" do
    data = <<128, 4, 125, 148, 46>>
    assert Unpickler.load!(data) == {%{}, ""}

    data =
      <<128, 4, 149, 17, 0, 0, 0, 0, 0, 0, 0, 125, 148, 40, 140, 1, 120, 148, 75, 1, 140, 1, 121,
        148, 75, 2, 117, 46>>

    assert Unpickler.load!(data) == {%{"x" => 1, "y" => 2}, ""}
  end

  test "set" do
    data = <<128, 4, 143, 148, 46>>
    assert Unpickler.load!(data) == {MapSet.new(), ""}

    data = <<128, 4, 149, 9, 0, 0, 0, 0, 0, 0, 0, 143, 148, 40, 75, 1, 75, 2, 144, 46>>
    assert Unpickler.load!(data) == {MapSet.new([1, 2]), ""}
  end

  test "frozenset" do
    data = <<128, 4, 149, 4, 0, 0, 0, 0, 0, 0, 0, 40, 145, 148, 46>>
    assert Unpickler.load!(data) == {MapSet.new(), ""}

    data = <<128, 4, 149, 8, 0, 0, 0, 0, 0, 0, 0, 40, 75, 1, 75, 2, 145, 148, 46>>
    assert Unpickler.load!(data) == {MapSet.new([1, 2]), ""}
  end

  test "string" do
    data = <<128, 4, 149, 4, 0, 0, 0, 0, 0, 0, 0, 140, 0, 148, 46>>
    assert Unpickler.load!(data) == {"", ""}

    data = <<128, 4, 149, 8, 0, 0, 0, 0, 0, 0, 0, 140, 4, 116, 101, 115, 116, 148, 46>>
    assert Unpickler.load!(data) == {"test", ""}

    data =
      <<128, 4, 149, 13, 0, 0, 0, 0, 0, 0, 0, 140, 9, 116, 101, 115, 116, 32, 240, 159, 152, 186,
        148, 46>>

    assert Unpickler.load!(data) == {"test 😺", ""}
  end

  test "bytes" do
    data = <<128, 4, 149, 4, 0, 0, 0, 0, 0, 0, 0, 67, 0, 148, 46>>
    assert Unpickler.load!(data) == {<<>>, ""}

    data = <<128, 4, 149, 6, 0, 0, 0, 0, 0, 0, 0, 67, 2, 1, 2, 148, 46>>
    assert Unpickler.load!(data) == {<<1, 2>>, ""}
  end

  test "bytearray" do
    data =
      <<128, 4, 149, 29, 0, 0, 0, 0, 0, 0, 0, 140, 8, 98, 117, 105, 108, 116, 105, 110, 115, 148,
        140, 9, 98, 121, 116, 101, 97, 114, 114, 97, 121, 148, 147, 148, 41, 82, 148, 46>>

    assert Unpickler.load!(data) == {<<>>, ""}

    data =
      <<128, 4, 149, 35, 0, 0, 0, 0, 0, 0, 0, 140, 8, 98, 117, 105, 108, 116, 105, 110, 115, 148,
        140, 9, 98, 121, 116, 101, 97, 114, 114, 97, 121, 148, 147, 148, 67, 2, 1, 2, 148, 133,
        148, 82, 148, 46>>

    assert Unpickler.load!(data) == {<<1, 2>>, ""}
  end

  test "bytearray in protocol 5" do
    data = <<128, 5, 149, 11, 0, 0, 0, 0, 0, 0, 0, 150, 0, 0, 0, 0, 0, 0, 0, 0, 148, 46>>
    assert Unpickler.load!(data) == {<<>>, ""}

    data = <<128, 5, 149, 13, 0, 0, 0, 0, 0, 0, 0, 150, 2, 0, 0, 0, 0, 0, 0, 0, 1, 2, 148, 46>>
    assert Unpickler.load!(data) == {<<1, 2>>, ""}
  end

  test "global" do
    data =
      <<128, 4, 149, 21, 0, 0, 0, 0, 0, 0, 0, 140, 8, 100, 97, 116, 101, 116, 105, 109, 101, 148,
        140, 4, 100, 97, 116, 101, 148, 147, 148, 46>>

    assert Unpickler.load!(data) == {%Unpickler.Global{scope: "datetime", name: "date"}, ""}
  end

  describe "object" do
    test "plain object" do
      # class Point:
      #   def __init__(self, x, y):
      #     self.x = x
      #     self.y = y
      #
      # Point(1, 1)

      data =
        <<128, 4, 149, 42, 0, 0, 0, 0, 0, 0, 0, 140, 8, 95, 95, 109, 97, 105, 110, 95, 95, 148,
          140, 5, 80, 111, 105, 110, 116, 148, 147, 148, 41, 129, 148, 125, 148, 40, 140, 1, 120,
          148, 75, 1, 140, 1, 121, 148, 75, 1, 117, 98, 46>>

      assert Unpickler.load!(data) ==
               {%Unpickler.Object{
                  constructor: "__main__.Point.__new__",
                  args: [%Unpickler.Global{scope: "__main__", name: "Point"}],
                  kwargs: %{},
                  state: %{"x" => 1, "y" => 1},
                  append_items: [],
                  set_items: []
                }, ""}
    end

    test "object with __reduce__" do
      # class Point:
      #   def __init__(self, x, y):
      #     self.x = x
      #     self.y = y
      #
      #   def __reduce__(self):
      #     return (Point, (self.x, self.y))
      #
      # Point(1, 1)

      data =
        <<128, 4, 149, 30, 0, 0, 0, 0, 0, 0, 0, 140, 8, 95, 95, 109, 97, 105, 110, 95, 95, 148,
          140, 5, 80, 111, 105, 110, 116, 148, 147, 148, 75, 1, 75, 1, 134, 148, 82, 148, 46>>

      assert Unpickler.load!(data) ==
               {%Unpickler.Object{
                  constructor: "__main__.Point",
                  args: [1, 1],
                  kwargs: %{},
                  state: nil,
                  append_items: [],
                  set_items: []
                }, ""}
    end

    test "object with __reduce__ specifying append and set iterators" do
      # class Point:
      #   def __init__(self, x, y):
      #     self.x = x
      #     self.y = y
      #
      #   def __reduce__(self):
      #     append_iter = iter([1, 2])
      #     set_iter = iter([("a", 1), ("b", 2)])
      #     return (Point, (self.x, self.y), None, append_iter, set_iter)
      #
      # x = Point(1, 1)

      data =
        <<128, 4, 149, 50, 0, 0, 0, 0, 0, 0, 0, 140, 8, 95, 95, 109, 97, 105, 110, 95, 95, 148,
          140, 5, 80, 111, 105, 110, 116, 148, 147, 148, 75, 1, 75, 1, 134, 148, 82, 148, 40, 75,
          1, 75, 2, 101, 40, 140, 1, 97, 148, 75, 1, 140, 1, 98, 148, 75, 2, 117, 46>>

      assert Unpickler.load!(data) ==
               {%Unpickler.Object{
                  constructor: "__main__.Point",
                  args: [1, 1],
                  kwargs: %{},
                  state: nil,
                  append_items: [1, 2],
                  set_items: [{"a", 1}, {"b", 2}]
                }, ""}
    end

    test "object with __reduce__ returning class method" do
      # class Point:
      #   def __init__(self, x, y):
      #     self.x = x
      #     self.y = y
      #
      #   @classmethod
      #   def _reconstruct(cls, x, y):
      #     return cls(x, y)
      #
      #   def __reduce__(self):
      #     return (Point._reconstruct, (self.x, self.y))
      #
      # Point(1, 1)

      data =
        <<128, 4, 149, 72, 0, 0, 0, 0, 0, 0, 0, 140, 8, 98, 117, 105, 108, 116, 105, 110, 115,
          148, 140, 7, 103, 101, 116, 97, 116, 116, 114, 148, 147, 148, 140, 8, 95, 95, 109, 97,
          105, 110, 95, 95, 148, 140, 5, 80, 111, 105, 110, 116, 148, 147, 148, 140, 12, 95, 114,
          101, 99, 111, 110, 115, 116, 114, 117, 99, 116, 148, 134, 148, 82, 148, 75, 1, 75, 1,
          134, 148, 82, 148, 46>>

      assert Unpickler.load!(data) ==
               {%Unpickler.Object{
                  constructor: "__main__.Point._reconstruct",
                  args: [1, 1],
                  kwargs: %{},
                  state: nil,
                  append_items: [],
                  set_items: []
                }, ""}
    end

    test "object with __getnewargs__" do
      # class Point:
      #   def __init__(self, x, y):
      #     self.x = x
      #     self.y = y
      #
      #   def __getnewargs__(self):
      #     return ("arg",)
      #
      # Point(1, 1)

      data =
        <<128, 4, 149, 49, 0, 0, 0, 0, 0, 0, 0, 140, 8, 95, 95, 109, 97, 105, 110, 95, 95, 148,
          140, 5, 80, 111, 105, 110, 116, 148, 147, 148, 140, 3, 97, 114, 103, 148, 133, 148, 129,
          148, 125, 148, 40, 140, 1, 120, 148, 75, 1, 140, 1, 121, 148, 75, 1, 117, 98, 46>>

      assert Unpickler.load!(data) ==
               {%Unpickler.Object{
                  constructor: "__main__.Point.__new__",
                  args: [%Unpickler.Global{scope: "__main__", name: "Point"}, "arg"],
                  kwargs: %{},
                  state: %{"x" => 1, "y" => 1},
                  append_items: [],
                  set_items: []
                }, ""}
    end

    test "object with __getnewargs_ex__" do
      # class Point:
      #   def __init__(self, x, y):
      #     self.x = x
      #     self.y = y
      #
      #   def __getnewargs_ex__(self):
      #     return (("arg",), {"kwarg": 1})
      #
      # Point(1, 1)

      data =
        <<128, 4, 149, 62, 0, 0, 0, 0, 0, 0, 0, 140, 8, 95, 95, 109, 97, 105, 110, 95, 95, 148,
          140, 5, 80, 111, 105, 110, 116, 148, 147, 148, 140, 3, 97, 114, 103, 148, 133, 148, 125,
          148, 140, 5, 107, 119, 97, 114, 103, 148, 75, 1, 115, 146, 148, 125, 148, 40, 140, 1,
          120, 148, 75, 1, 140, 1, 121, 148, 75, 1, 117, 98, 46>>

      assert Unpickler.load!(data) ==
               {%Unpickler.Object{
                  constructor: "__main__.Point.__new__",
                  args: [%Unpickler.Global{scope: "__main__", name: "Point"}, "arg"],
                  kwargs: %{"kwarg" => 1},
                  state: %{"x" => 1, "y" => 1},
                  append_items: [],
                  set_items: []
                }, ""}
    end

    test "object with __getstate__" do
      # class Point:
      #   def __init__(self, x, y):
      #     self.x = x
      #     self.y = y
      #
      #   def __getstate__(self):
      #     return (self.x, self.y)
      #
      #   def __setstate__(self, state):
      #     (x, y) = state
      #     self.x = x
      #     self.y = y
      #
      # Point(1, 1)

      data =
        <<128, 4, 149, 32, 0, 0, 0, 0, 0, 0, 0, 140, 8, 95, 95, 109, 97, 105, 110, 95, 95, 148,
          140, 5, 80, 111, 105, 110, 116, 148, 147, 148, 41, 129, 148, 75, 1, 75, 1, 134, 148, 98,
          46>>

      assert Unpickler.load!(data) ==
               {%Unpickler.Object{
                  constructor: "__main__.Point.__new__",
                  args: [%Unpickler.Global{scope: "__main__", name: "Point"}],
                  kwargs: %{},
                  state: {1, 1},
                  append_items: [],
                  set_items: []
                }, ""}
    end
  end

  test "custom object resolver" do
    data =
      <<128, 4, 149, 30, 0, 0, 0, 0, 0, 0, 0, 140, 8, 95, 95, 109, 97, 105, 110, 95, 95, 148, 140,
        5, 80, 111, 105, 110, 116, 148, 147, 148, 75, 1, 75, 1, 134, 148, 82, 148, 46>>

    object_resolver = fn
      %{constructor: "__main__.Point", args: [x, y]} ->
        {:ok, {:point, x, y}}

      _ ->
        :error
    end

    assert Unpickler.load!(data, object_resolver: object_resolver) == {{:point, 1, 1}, ""}
  end

  test "persistent id resolver" do
    # import pickle
    #
    # class CustomPickler(pickle.Pickler):
    #   def persistent_id(self, obj):
    #     if obj == "persistent":
    #       return "id"
    #     else:
    #       return None
    #
    # [1, "persistent"]

    data =
      <<128, 4, 149, 13, 0, 0, 0, 0, 0, 0, 0, 93, 148, 40, 75, 1, 140, 2, 105, 100, 148, 81, 101,
        46>>

    persistent_id_resolver = fn "id" -> "persistent" end

    assert Unpickler.load!(data, persistent_id_resolver: persistent_id_resolver) ==
             {[1, "persistent"], ""}
  end

  test "raises on missing persistent id resolver" do
    data =
      <<128, 4, 149, 13, 0, 0, 0, 0, 0, 0, 0, 93, 148, 40, 75, 1, 140, 2, 105, 100, 148, 81, 101,
        46>>

    assert_raise RuntimeError,
                 ~r/encountered persistent id: "id", but no resolver was specified/,
                 fn ->
                   Unpickler.load!(data)
                 end
  end

  test "handles multiple references to the same object" do
    # l = [1, 2]
    # x = (l, l)

    data =
      <<128, 4, 149, 13, 0, 0, 0, 0, 0, 0, 0, 93, 148, 40, 75, 1, 75, 2, 101, 104, 0, 134, 148,
        46>>

    assert Unpickler.load!(data) == {{[1, 2], [1, 2]}, ""}
  end

  test "raises on unsupported pickle version" do
    data = <<128, 6, 75, 1, 46>>

    assert_raise RuntimeError, "unsupported pickle protocol: 6", fn ->
      Unpickler.load!(data)
    end
  end

  test "returns remaining binary data" do
    data = <<128, 4, 75, 1, 46, 0, 0, 0, 0>>
    assert Unpickler.load!(data) == {1, <<0, 0, 0, 0>>}
  end

  test "protocol 0" do
    data = <<73, 49, 10, 46>>
    assert Unpickler.load!(data) == {1, ""}

    data = <<76, 49, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 76, 10, 46>>
    assert Unpickler.load!(data) == {10_000_000_000, ""}

    data = <<70, 49, 46, 48, 10, 46>>
    assert Unpickler.load!(data) == {1.0, ""}

    data = <<73, 48, 49, 10, 46>>
    assert Unpickler.load!(data) == {true, ""}

    data = <<73, 48, 48, 10, 46>>
    assert Unpickler.load!(data) == {false, ""}

    data = <<40, 108, 112, 48, 10, 73, 49, 10, 97, 73, 50, 10, 97, 46>>
    assert Unpickler.load!(data) == {[1, 2], ""}

    data = <<40, 73, 49, 10, 73, 50, 10, 116, 112, 48, 10, 46>>
    assert Unpickler.load!(data) == {{1, 2}, ""}

    data =
      <<40, 100, 112, 48, 10, 86, 120, 10, 112, 49, 10, 73, 49, 10, 115, 86, 121, 10, 112, 50, 10,
        73, 50, 10, 115, 46>>

    assert Unpickler.load!(data) == {%{"x" => 1, "y" => 2}, ""}

    data = <<86, 116, 101, 115, 116, 10, 112, 48, 10, 46>>
    assert Unpickler.load!(data) == {"test", ""}

    data =
      <<99, 100, 97, 116, 101, 116, 105, 109, 101, 10, 100, 97, 116, 101, 10, 112, 48, 10, 46>>

    assert Unpickler.load!(data) == {%Unpickler.Global{scope: "datetime", name: "date"}, ""}
  end
end
