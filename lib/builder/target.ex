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
    } |> maybe_fix_libc()
  end

  def init_target({os, cpu}, debug?) do
    init_target({os, cpu, :none}, debug?) |> maybe_fix_libc()
  end

  @spec make_triplet(Burrito.Builder.Target.t()) :: String.t()
  def make_triplet(%Target{} = target) do
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

  # PONDER: is it ok to assume :gnu here?
  # maybe we should assume the host OS's libc instead (if they're running linux)
  defp maybe_fix_libc(%Target{os: :linux, libc: :none} = target) do
    %Target{target | libc: :gnu}
  end

  defp maybe_fix_libc(target), do: target
end
