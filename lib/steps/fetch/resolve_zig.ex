defmodule Burrito.Steps.Fetch.ResolveZig do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Util.ZigResolver

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    case ZigResolver.resolve() do
      {:ok, zig_bin} ->
        %Context{context | zig_bin: zig_bin}

      {:error, reason} ->
        Log.error(:step, reason)
        %Context{context | halted: true}
    end
  end
end
