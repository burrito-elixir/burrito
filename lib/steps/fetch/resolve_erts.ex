defmodule Burrito.Steps.Fetch.ResolveERTS do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Target
  alias Burrito.Builder.Step
  alias Burrito.Util.ERTSResolver

  @behaviour Step

  # A list of the pre compiled ERTS builds we provide
  # using the `erlang-builder` repo
  @pre_compiled_supported_tuples [
    # {os, cpu, libc (linux only)}
    {:windows, :x86_64, nil},
    {:darwin, :x86_64, nil},
    {:linux, :x86_64, :glibc},
    {:linux, :x86_64, :musl}
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
      %Context{context | target: resolved_erts_target}
    end
  end

  defp pass_precompile_check?(%Target{erts_source: {:precompiled, _}} = target) do
    libc = Keyword.get(target.qualifiers, :libc)
    {target.os, target.cpu, libc} in @pre_compiled_supported_tuples
  end

  defp pass_precompile_check?(_) do
    true
  end
end
