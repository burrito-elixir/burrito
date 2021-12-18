defmodule Burrito.Steps.Fetch.InitBuild do
  @moduledoc """
  This build step does some sanity checking between the target we're building for, and the host machine
  If it determines we are cross-building, it will check to ensure an ERTS build is available for the target.
  """
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Target
  alias Burrito.Builder.Step
  alias Burrito.Util

  # This is a list of precompiled ERTS releases we provide in the Burrito project
  # any other build tuples will need to be provided using the `:local_erts` release option.
  @pre_compiled_supported_tuples [
    #{os, cpu, libc (linux only)}
    {:windows, :x86_64, nil},
    {:darwin, :x86_64, nil},
    {:linux, :x86_64, :glibc},
    {:linux, :x86_64, :musl}
  ]

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    context
  end
end
