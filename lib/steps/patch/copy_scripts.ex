defmodule Burrito.Steps.Patch.CopyScripts do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    context
  end
end
