defmodule Burrito.Steps.Fetch.Init do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step
  alias Burrito.Builder.Log
  alias Burrito.Util

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    work_dir = System.tmp_dir!() |> Path.join(["burrito_build_#{random_id}"])
    File.cp_r(context.mix_release.path, work_dir, fn _, _ -> true end)

    Log.info(:step, "Working directory: #{work_dir}")

    new_context = %Context{context | work_dir: work_dir}
    clean_work_dir(new_context)
  end

  defp clean_work_dir(%Context{} = context) do
    # we need to clean out any ERTS versions and releases that don't match the one we are currently building
    # we're in a copied work_dir so we can safely just delete anything in here

    current_erts_version = Util.get_erts_version()
    current_release_version = context.mix_release.version

    releases_dirs = Path.join(context.work_dir, ["/releases", "/*.*.*"]) |> Path.wildcard()
    erts_dirs = Path.join(context.work_dir, ["/erts-*"]) |> Path.wildcard()

    to_be_deleted =
      Enum.filter(releases_dirs, fn dir -> Path.basename(dir) != current_release_version end) ++
        Enum.filter(erts_dirs, fn dir -> Path.basename(dir) != "erts-#{current_erts_version}" end)

    Enum.map(to_be_deleted, &File.rm_rf!/1)

    context
  end
end
