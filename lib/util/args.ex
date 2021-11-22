defmodule Burrito.Util.Args do
  @moduledoc """
  This module provides a method to help fetch CLI arguments passed down
  from the Zig wrapper binary. To get around the many issues of escaping quotes
  in Windows, we base64 encode each argument before passing it to the Erlang VM.
  `get_arguments/0` will decode them automatically for you.
  """

  @spec get_arguments :: list(String.t())
  def get_arguments do
    if is_windows?() && args_are_encoded?() do
      {prefix, trimmed} = :init.get_plain_arguments() |> Enum.split(4)
      decoded = Enum.map(trimmed, fn arg ->
        case Base.decode64(to_string(arg), padding: false) do
          {:ok, decoded_arg} -> decoded_arg
          :error -> to_string(arg)
        end
      end)

    prefix ++ decoded
    else
      :init.get_plain_arguments() |> Enum.map(fn arg -> to_string(arg) end)
    end
  end

  defp is_windows? do
    match?({:win32, _}, :os.type())
  end

  defp args_are_encoded? do
    System.get_env("_ARGUMENTS_ENCODED", "0") == "1"
  end
end
