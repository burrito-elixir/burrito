defmodule Burrito.Builder.Target do
  use TypedStruct

  alias __MODULE__
  alias Burrito.Builder.Log
  alias Burrito.Util

  typedstruct do
    field(:cpu, atom(), enforce: true)
    field(:os, atom(), enforce: true)
    field(:libc, atom(), enforce: true)
    field(:otp_version, String.t(), enforce: true)
    field(:debug?, boolean(), enforce: true)
  end

  @spec init_target({atom(), atom()} | {atom(), atom(), atom()}, boolean()) ::
          Burrito.Builder.Target.t()
  def init_target({os, cpu, libc}, debug?) do
    %Target{
      cpu: cpu,
      os: os,
      libc: libc,
      otp_version: Util.get_otp_version(),
      debug?: debug?
    }
    |> maybe_fix_libc()
  end

  def init_target({os, cpu}, debug?) do
    init_target({os, cpu, :none}, debug?) |> maybe_fix_libc()
  end

  @spec make_triplet(Burrito.Builder.Target.t()) :: String.t()
  def make_triplet(%Target{} = target) do
    os =
      case target.os do
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

  @spec string_to_tuple(any) :: :error | {atom, atom, atom}
  def string_to_tuple(string) do
    parts = String.trim(string) |> String.downcase() |> String.split("-")

    case parts do
      [maybe_old_target] ->
        maybe_translate_old_target(String.to_existing_atom(maybe_old_target))

      [cpu, os] ->
        {String.to_existing_atom(os), String.to_existing_atom(cpu), :none}

      [cpu, os, libc] ->
        {String.to_existing_atom(os), String.to_existing_atom(cpu), String.to_existing_atom(libc)}

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  @spec string_to_target(any) :: :error | Burrito.Builder.Target.t()
  def string_to_target(string) do
    tuple = string_to_tuple(string)

    if tuple == :error do
      :error
    else
      init_target(tuple, false)
    end
  end

  @spec maybe_translate_old_target(:darwin | :linux | :linux_musl | :win64 | {any, any, any}) ::
          {any, any, any}
  def maybe_translate_old_target(old_target) when old_target in [:darwin, :win64, :linux, :linux_musl] do
    Log.warning(:build, "You have specified an old-style build target, please move to using the newer format of build targets. See the Burrito README for examples.")
    case old_target do
      :darwin -> {:darwin, :x86_64, :none}
      :win64 -> {:windows, :x86_64, :none}
      :linux -> {:linux, :x86_64, :gnu}
      :linux_musl -> {:linux, :x86_64, :musl}
    end
  end

  def maybe_translate_old_target({_, _, _} = not_old_target), do: not_old_target

  # PONDER: is it ok to assume :gnu here?
  # maybe we should assume the host OS's libc instead (if they're running linux)
  defp maybe_fix_libc(%Target{os: :linux, libc: :none} = target) do
    %Target{target | libc: :gnu}
  end

  defp maybe_fix_libc(target), do: target
end
