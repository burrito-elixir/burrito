defmodule Burrito.Util.Args do
  @moduledoc """
  This module provides a method to help fetch CLI arguments, whether passed down
  from the Zig wrapper binary or from the the system.
  """

  @doc """
  Get CLI arguments passed down from the Zig wrapper binary. Do note that this will get OTP
  runtime arguments when called outside of a Burrito-built context. You may consider
  `argv/0` as a more general alternative.
  """
  @spec get_arguments :: list(String.t())
  def get_arguments do
    :init.get_plain_arguments() |> Enum.map(&to_string/1)
  end

  @doc """
  Get the arguments from the CLI, regardless if run under Burrito or not.
  """
  @spec argv :: list(String.t())
  def argv do
    if Burrito.Util.running_standalone?() do
      get_arguments()
    else
      System.argv()
    end
  end

  @doc """
  Returns the path of the wrapper binary that launched this application.
  If not currently inside a Burrito wrapped application, returns `:not_in_burrito`.
  """
  @spec get_bin_path() :: binary() | :not_in_burrito
  def get_bin_path() do
    env_value = System.get_env("__BURRITO_BIN_PATH")

    if env_value != nil do
      env_value
    else
      :not_in_burrito
    end
  end
end
