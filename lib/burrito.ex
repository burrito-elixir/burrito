defmodule Burrito do
  alias Burrito.Builder
  alias Burrito.Builder.Log

  @zig_version_expected %Version{major: 0, minor: 15, patch: 1}
  @openssl_version %Version{major: 3, minor: 5, patch: 1}
  @musl_version %Version{major: 1, minor: 2, patch: 5}

  @spec wrap(Mix.Release.t()) :: Mix.Release.t()
  def wrap(%Mix.Release{} = release) do
    pre_check()
    Builder.build(release)
  end

  @spec register_erts_resolver(module()) :: :ok
  def register_erts_resolver(module) when is_atom(module) do
    Application.put_env(:burrito, :erts_resolver, module)
  end

  @spec get_versions() :: map()
  def get_versions() do
    %{
      zig: @zig_version_expected,
      openssl: @openssl_version,
      musl: @musl_version
    }
  end

  defp pre_check() do
    if Enum.any?(~w(zig xz), &(System.find_executable(&1) == nil)) do
      Log.error(
        :build,
        "You MUST have `zig` and `xz` installed to use Burrito, we couldn't find all of them in your PATH!"
      )

      exit(1)
    end

    if Enum.all?(~w(7z 7zz), &(System.find_executable(&1) == nil)) do
      Log.warning(
        :build,
        "We couldn't find 7z/7zz in your PATH, 7z/7zz is required to build Windows releases. They will fail if you don't fix this!"
      )
    end

    check_zig_version()
  end

  defp check_zig_version() do
    {res, _} = System.cmd("zig", ["version"])
    version = String.trim(res) |> Version.parse!()

    if version != @zig_version_expected do
      Log.error(
        :build,
        "Your Zig version does not match the one Burrito requires! We need `#{Version.to_string(@zig_version_expected)}`, you have: `#{Version.to_string(version)}`"
      )

      exit(1)
    end
  end
end
