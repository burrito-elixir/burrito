defmodule Burrito.Builder.Context do
  use TypedStruct

  alias Burrito.Builder.Target

  @type erts_location :: nil | {:release | :local | :url | :unpacked | :unresolved, term()}

  typedstruct enforce: true do
    field(:target, Target.t())
    field(:mix_release, Mix.Release.t())
    field(:work_dir, String.t())
    field(:self_dir, String.t())
    field(:extra_build_env, list({String.t(), String.t()}))
    field(:halted, boolean())
  end
end
