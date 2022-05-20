defmodule Unpickler.Global do
  @moduledoc """
  Represents a reference to a global class or function.
  """

  defstruct [:scope, :name]

  @doc false
  def new(scope, name) do
    %__MODULE__{scope: scope, name: name}
  end

  @doc false
  def path(global) do
    scope_to_path(global.scope) <> "." <> global.name
  end

  defp scope_to_path(scope) when is_binary(scope), do: scope
  defp scope_to_path(%__MODULE__{} = scope), do: path(scope)
end
