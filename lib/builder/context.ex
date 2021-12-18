defmodule Burrito.Builder.Context do
  use TypedStruct

  alias Burrito.Builder.Target

  @type erts_location :: nil | {:release | :local | :url | :unpacked, term()}

  typedstruct enforce: true do
    field :target, Target.t()
    field :mix_release, Mix.Release.t()
    field :work_dir, String.t()
    field :self_dir, String.t()
    field :halt, boolean()
  end
end
