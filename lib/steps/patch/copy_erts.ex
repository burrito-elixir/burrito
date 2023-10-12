defmodule Burrito.Steps.Patch.CopyERTS do
  @moduledoc """
  This step copies the new ERTS bins into the release, as well as replaces built-in NIFs.
  """
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    case context.target.erts_source do
      # nothing to do
      {:runtime, _} ->
        context

      {:local_unpacked, [path: location]} ->
        # copy unpacked bins into release working directory
        do_copy(location, context)
    end

    context
  end

  defp do_copy(erts_location, %Context{} = context) do
    Log.info(:step, "Replacing ERTS binaries...")

    # Clean out current bins
    dest_bin_path =
      Path.join(context.work_dir, ["erts-*/", "bin/"])
      |> Path.expand()
      |> Path.wildcard()
      |> List.first()

    File.rm_rf!(dest_bin_path)
    File.mkdir!(dest_bin_path)

    # Copy in new bins from unpacked ERTS
    unpacked_path = recursively_find_dir([erts_location], ~r/^erts-.*$/)

    src_bin_path = Path.join(unpacked_path, ["bin/"])

    File.cp_r!(src_bin_path, dest_bin_path)

    # The ERTS comes with some pre-built NIFs, so we need to replace those

    src_lib_path = recursively_find_dir([erts_location], ~r/^lib$/)

    dest_lib_path = Path.join(context.work_dir, ["lib/"]) |> Path.expand()

    # List the DLL/SO files that come from our replacement ERTS
    # The new ERTS is treated as the "authoritative" ERTS, some DLLs/SOs may exist in it
    # That do not exist in the host/source ERTS. We'll log when we replace a library file
    to_copy =
      Path.join(erts_location, "*/lib/**/*.{so,dll,exe}") |> Path.expand() |> Path.wildcard()

    Enum.each(to_copy, fn file_to_copy ->
      destination_file_path = String.replace(file_to_copy, src_lib_path, dest_lib_path)

      possible_file_to_replace =
        String.replace_suffix(destination_file_path, Path.extname(to_copy), "*.{so,dll}")
        |> Path.wildcard()
        |> List.first()

      full_directory = Path.dirname(destination_file_path)
      File.mkdir_p!(full_directory)

      if possible_file_to_replace != nil do
        File.rm!(possible_file_to_replace)

        Log.warning(
          :step,
          "Overwriting NIF library #{possible_file_to_replace} with #{file_to_copy}"
        )
      end

      File.copy!(file_to_copy, destination_file_path)

      Log.success(
        :step,
        "Installed NIF library #{destination_file_path}"
      )
    end)
  end

  defp recursively_find_dir([], _target_dir_pattern), do: nil

  defp recursively_find_dir([current_path | rest], target_dir_pattern) do
    case String.match?(Path.basename(current_path), target_dir_pattern) do
      true ->
        Path.expand(current_path)

      false ->
        dir_paths =
          for file_name <- File.ls!(current_path),
              File.dir?(Path.join(current_path, file_name)),
              not String.starts_with?(file_name, ".") do
            Path.join(current_path, file_name)
          end

        recursively_find_dir(rest ++ dir_paths, target_dir_pattern)
    end
  end
end
