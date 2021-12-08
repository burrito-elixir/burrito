defmodule Burrito.Builder.Target do
  use TypedStruct

  alias __MODULE__
  alias Burrito.Util

  typedstruct do
    field :cpu, atom(), enforce: true
    field :os, atom(), enforce: true
    field :libc, atom(), enforce: true
    field :otp_version, String.t(), enforce: true
    field :debug?, boolean(), enforce: true
  end

  @spec init_target({atom(), atom()} | {atom(), atom(), atom()}, boolean()) :: Burrito.Builder.Target.t()
  def init_target({os, cpu, libc}, debug?) do
    %Target{
      cpu: cpu,
      os: os,
      libc: libc,
      otp_version: Util.get_otp_version(),
      debug?: debug?
    }
  end

  def init_target({os, cpu}, debug?) do
    init_target({os, cpu, :none}, debug?)
  end

  @spec make_zig_triplet(Burrito.Builder.Target.t()) :: String.t()
  def make_zig_triplet(%Target{} = target) do
    os = case target.os do
      :darwin -> "macos"
      :windows -> "windows"
      :linux -> "linux"
    end

    triplet = "#{target.cpu}-#{os}"

    if target.libc != :none do
      triplet <> "-#{target.libc}"
    else
      triplet
    end
  end
end
