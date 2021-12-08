defmodule Burrito.Steps.Fetch.FetchERTS do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step
  alias Burrito.Util.FileCache

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    case context.erts_location do
      nil -> %Context{context | halt: true, errors: ["Failed to locate a useable ERTS release, local or remote. The version of Erlang you are trying to ship may be unsupported!"]}
      :local -> context # nothing to do if we are using the local ERTS installation
      _location -> load_remote_erts(context)
    end
  end

  defp load_remote_erts(%Context{} = context) do
    # TODO: copy logic over from otp_fetcher module
    context
  end
end
