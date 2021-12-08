defmodule Burrito.Builder.Step do
  alias Burrito.Builder.Context

  @doc """
  This function is called when the step is to be executed by the build phase.
  It should return a context to be passed along to the next build step or phase.
  """
  @callback execute(Context.t()) :: Context.t()
end
