defmodule Kontrol.Helpers do
  @moduledoc false

  @doc ~S"""
  Apply a function to a value, but return the original value.

  Therefore the function is used only for its side effects.
  """
  @spec tap(any(), function()) :: any()
  def tap(value, fun \\ &IO.puts(inspect(&1))) do
    fun.(value)
    value
  end
end
