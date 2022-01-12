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
      Path.join(context.work_dir, ["erts-*/", "bin/"]) |> Path.expand() |> Path.wildcard() |> List.first()

    File.rm_rf!(dest_bin_path)
    File.mkdir!(dest_bin_path)

    # Copy in new bins from unpacked ERTS
    unpacked_path =
      Path.join(erts_location, ["otp-*/", "erts-*/"]) |> Path.expand() |> Path.wildcard() |> List.first()

    src_bin_path = Path.join(unpacked_path, ["bin/"])

    File.cp_r!(src_bin_path, dest_bin_path)

    # The ERTS comes with some pre-built NIFs, so we need to replace those
    libs_to_replace = Path.join(context.work_dir, "lib/**/*.{so,dll}") |> Path.expand() |> Path.wildcard()
    src_lib_path = Path.join(erts_location, ["otp-*/", "lib/"]) |> Path.expand() |> Path.wildcard() |> List.first()
    dest_lib_path = Path.join(context.work_dir, ["lib/"]) |> Path.expand()

    Enum.each(libs_to_replace, fn lib_file ->
      # This replaces the .so or .dll with a wildcard match of .so or .dll
      # that way it's more generic across ERTS targets (windows, linux, darwin, etc.)
      possible_src_path =
        String.replace(lib_file, dest_lib_path, src_lib_path)
        |> String.replace_suffix(Path.extname(lib_file), "*.{so,dll}")
        |> Path.expand()
        |> Path.wildcard()
        |> List.first()

      if possible_src_path && File.exists?(possible_src_path) do
        File.rm!(lib_file)
        File.copy!(possible_src_path, lib_file)

        Log.info(
          :step,
          "Replaced NIF \n\tOriginal: #{lib_file}\n\tReplacement: #{possible_src_path}"
        )
      else
        File.rm!(lib_file)

        Log.warning(
          :step,
          "We couldn't find a replacement for NIF\n\t#{lib_file}\n\tThe binary may not work!"
        )
      end
    end)
  end
end
