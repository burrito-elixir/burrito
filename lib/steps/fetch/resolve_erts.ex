defmodule Burrito.Steps.Fetch.ResolveERTS do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Target
  alias Burrito.Builder.Step
  alias Burrito.Util.ERTSResolver

  @behaviour Step

  # A list of the pre-compiled ERTS builds we provide
  @pre_compiled_supported_tuples [
    {:windows, :x86_64},
    {:darwin, :x86_64},
    {:darwin, :aarch64},
    {:linux, :x86_64},
    {:linux, :aarch64}
  ]

  @impl Step
  def execute(%Context{} = context) do
    if !pass_precompile_check?(context.target) do
      Log.error(
        :step,
        "We currently do not provide a pre-compiled ERTS release for your target's requested architecture and OS!"
      )

      %Context{context | halted: true}
    else
      Log.info(:step, "Resolving ERTS: #{inspect(context.target.erts_source)}")
      resolved_erts_target = ERTSResolver.resolve(context.target)

      case resolved_erts_target.erts_source do
        {:unresolved, _} ->
          Log.error(:step, "Cannot resolve ERTS, please check for errors in the log above.")
          %Context{context | halted: true}

        _ ->
          %Context{context | target: resolved_erts_target}
      end
    end
  end

  defp pass_precompile_check?(%Target{erts_source: {:precompiled, _}} = target) do
    {target.os, target.cpu} in @pre_compiled_supported_tuples
  end

  defp pass_precompile_check?(_) do
    true
  end
end
