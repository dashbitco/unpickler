defmodule Unpickler.Object do
  @moduledoc """
  Represents a Python object.

  This struct includes all the information that would be used for
  object reconstruction. Refer to the pickle documentation for more
  details.

  ## Information

  The following fields are available:

    * `:constructor` - name of the class or function called to build
      the object

    * `:args` - a list of arguments passed to the constructor

    * `:kwargs` - a map with keyword arguments passed to the constructor

    * `:state` - a value passed to the `__setstate__` method if applicable

    * `:append_items` - a list of values to append to the object

    * `:set_items` - a list of key-value pairs to set on the object

  """

  defstruct [:constructor, :args, :kwargs, :state, :append_items, :set_items]

  @doc false
  def new(global, args, kwargs) do
    %__MODULE__{
      constructor: Unpickler.Global.path(global),
      args: args,
      kwargs: kwargs,
      state: nil,
      append_items: [],
      set_items: []
    }
  end

  @doc false
  def set_state(object, state) do
    %{object | state: state}
  end

  @doc false
  def append_many(object, items) do
    update_in(object.append_items, &(&1 ++ items))
  end

  @doc false
  def set_many(object, pairs) do
    update_in(object.set_items, &(&1 ++ pairs))
  end
end
