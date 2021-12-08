defmodule Burrito.Builder.Context do
  use TypedStruct

  alias Burrito.Builder.Target

  typedstruct do
    field :target, Target.t(), enforce: true
    field :erts_location, String.t() | :local, enforce: true
    field :cross_build, boolean, enforce: true
    field :mix_release, Mix.Release.t(), enforce: true
    field :work_dir, String.t(), enforce: true
    field :warnings, list(String.t()), enforce: true
    field :errors, list(String.t()), enforce: true
    field :halt, boolean(), default: false
  end
end
