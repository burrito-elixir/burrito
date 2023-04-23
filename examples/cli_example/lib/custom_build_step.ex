defmodule ExampleCliApp.CustomBuildStep do
  alias Burrito.Builder.Step
  @behaviour Step

  @impl Step
  def execute(% Burrito.Builder.Context{} = context) do
    IO.puts("Custom build step!")
    IO.puts("Current Target: #{inspect(context.target)}")

    context
  end
end
