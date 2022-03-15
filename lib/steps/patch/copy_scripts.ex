defmodule Burrito.Steps.Patch.CopyScripts do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    copy_launch_scripts(context.self_dir, context.work_dir, context.mix_release.name)
    context
  end

  defp copy_launch_scripts(self_path, release_path, release_name) do
    release_name = to_string(release_name)
    src_dir = scripts_dir(self_path)
    scripts = launch_scripts(release_path, release_name)

    compile_context = [
      release_name: release_name
    ]

    for {src_name, dest_dir, dest_name} <- scripts do
      src_path = Path.join(src_dir, src_name)
      dest_path = Path.join(dest_dir, dest_name)

      src_text = EEx.eval_file(src_path, compile_context)

      File.write!(dest_path, src_text)
      File.chmod!(dest_path, 0o744)
    end
  end

  defp launch_scripts(release_path, release_name) do
    bins_dir = bins_dir(release_path)
    erts_dir = erts_dir(release_path)

    # Each script is a tuple of {src_name, dest_dir, dest_name}
    [
      {"posix_start.sh.eex", bins_dir, release_name},
      {"win_start.bat.eex", bins_dir, release_name <> ".bat"},
      {"posix_erl.sh.eex", erts_dir, "erl"},
      {"posix_erts_start.sh.eex", erts_dir, "start"}
    ]
  end

  defp scripts_dir(release_path) do
    Path.join(release_path, "src/scripts")
  end

  defp bins_dir(release_path) do
    Path.join(release_path, "bin")
  end

  defp erts_dir(release_path) do
    release_path
    |> Path.join("erts-*/bin")
    |> Path.expand()
    |> Path.wildcard()
    |> hd()
  end
end
