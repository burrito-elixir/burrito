defmodule Burrito.Steps.Patch.CopyERTS do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    case context.erts_location do
      {:release, _} -> context # nothing to do
      {:unpacked, location} ->
        do_copy(location, context)
    end
  end

  defp do_copy(location, %Context{} = context) do
    require IEx; IEx.pry
    context
  end
end
