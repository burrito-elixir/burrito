defmodule Burrito.Builder.Target do
  use TypedStruct

  alias __MODULE__
  alias Burrito.Builder.Log
  alias Burrito.Util

  @old_targets [:darwin, :win64, :linux, :linux_musl]

  @required_key [:os, :cpu]

  typedstruct do
    field :alias, atom(), enforce: true
    field :cpu, atom(), enforce: true
    field :os, atom(), enforce: true
    field :qualifiers, keyword(), enforce: true
    field :otp_version, String.t(), enforce: true
    field :debug?, boolean(), enforce: true
  end

  @spec init_target(keyword(), atom(), boolean()) :: Burrito.Builder.Target.t()
  def init_target(target, target_alias, debug?) do
    base = Keyword.take(target, @required_key)
    extra_qualifiers = Keyword.drop(target, @required_key)

    %Target{
      alias: target_alias,
      cpu: base[:cpu],
      os: base[:os],
      qualifiers: extra_qualifiers,
      otp_version: Util.get_otp_version(),
      debug?: debug?
    }
    |> maybe_fix_libc()
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

    if target.qualifiers[:libc] do
      "#{triplet}-#{target.qualifiers[:libc]}"
    else
      triplet
    end
  end

  @spec maybe_translate_old_target(atom()) :: keyword()
  def maybe_translate_old_target(old_target) when old_target in @old_targets do
    old_target = case old_target do
      :darwin -> [os: :darwin, cpu: :x86_64]
      :win64 -> [os: :windows, cpu: :x86_64]
      :linux -> [os: :linux, cpu: :x86_64, libc: :gnu]
      :linux_musl -> [os: :linux, cpu: :x86_64, libc: :musl]
    end

    Log.warning(
      :build,
      "You have specified an old-style build target, please move to using the newer format of build targets\n\t#{inspect(old_target)}\n\tSee the Burrito README for examples!"
    )

    old_target
  end

  def maybe_translate_old_target(not_old_target), do: not_old_target

  @spec get_old_targets :: [:darwin | :linux | :linux_musl | :win64]
  def get_old_targets do
    @old_targets
  end

  # PONDER: is it ok to assume :gnu here?
  # maybe we should assume the host OS's libc instead (if they're running linux)
  defp maybe_fix_libc(%Target{os: :linux} = target) do
    if !target.qualifiers[:libc] do
      qualifiers = Keyword.put(target.qualifiers, :libc, :gnu)
      %Target{target | qualifiers: qualifiers}
    else
      target
    end
  end

  defp maybe_fix_libc(target), do: target
end
