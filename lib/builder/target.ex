defmodule Burrito.Builder.Target do
  use TypedStruct

  alias __MODULE__
  alias Burrito.Builder.Log
  alias Burrito.Util

  @old_targets [:darwin, :win64, :linux, :linux_musl]

  @type build_tuple :: {atom(), atom(), keyword()} | {atom(), atom()}

  typedstruct do
    field :alias, atom(), enforce: true
    field :cpu, atom(), enforce: true
    field :os, atom(), enforce: true
    field :qualifiers, keyword(), enforce: true
    field :otp_version, String.t(), enforce: true
    field :debug?, boolean(), enforce: true
  end

  @spec init_target(build_tuple(), atom(), boolean()) :: Burrito.Builder.Target.t()
  def init_target({os, cpu, build_qualifiers}, target_alias, debug?)
      when is_list(build_qualifiers) do
    %Target{
      alias: target_alias,
      cpu: cpu,
      os: os,
      qualifiers: build_qualifiers,
      otp_version: Util.get_otp_version(),
      debug?: debug?
    }
    |> maybe_fix_libc()
  end

  def init_target({os, cpu}, target_alias, debug?) do
    init_target({os, cpu, [libc: :none]}, target_alias, debug?) |> maybe_fix_libc()
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

    if target.qualifiers[:libc] != :none do
      "#{triplet}-#{target.qualifiers[:libc]}"
    else
      triplet
    end
  end

  @spec maybe_translate_old_target(:darwin | :linux | :linux_musl | :win64 | build_tuple()) ::
          build_tuple() | :error
  def maybe_translate_old_target(old_target) when old_target in @old_targets do
    Log.warning(
      :build,
      "You have specified an old-style build target, please move to using the newer format of build targets\n\t{os, cpu, [extra_options]}\n\tSee the Burrito README for examples!"
    )

    case old_target do
      :darwin -> {:darwin, :x86_64}
      :win64 -> {:windows, :x86_64}
      :linux -> {:linux, :x86_64, [libc: :gnu]}
      :linux_musl -> {:linux, :x86_64, [libc: :musl]}
    end
  end

  def maybe_translate_old_target({_, _, _} = not_old_target), do: not_old_target
  def maybe_translate_old_target({_, _} = not_old_target), do: not_old_target
  def maybe_translate_old_target(_), do: :error

  @spec get_old_targets :: [:darwin | :linux | :linux_musl | :win64]
  def get_old_targets do
    @old_targets
  end

  # PONDER: is it ok to assume :gnu here?
  # maybe we should assume the host OS's libc instead (if they're running linux)
  defp maybe_fix_libc(%Target{os: :linux} = target) do
    if !target.qualifiers[:libc] || target.qualifiers[:libc] == :none do
      qualifiers = [libc: :gnu] ++ target.qualifiers
      %Target{target | qualifiers: qualifiers}
    else
      target
    end
  end

  defp maybe_fix_libc(target), do: target
end
