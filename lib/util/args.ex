defmodule Burrito.Util.Args do
  @moduledoc """
  This module provides a method to help fetch CLI arguments passed down
  from the Zig wrapper binary.
  """

  @spec get_arguments :: list(String.t())
  def get_arguments do
    :init.get_plain_arguments() |> Enum.map(&to_string/1)
  end
end
