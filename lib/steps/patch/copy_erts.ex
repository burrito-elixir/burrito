defmodule Burrito.Steps.Patch.CopyERTS do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step

  require Logger

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    case context.erts_location do
      # nothing to do
      {:release, _} ->
        context

      {:unpacked, location} ->
        # copy unpacked bins into release working directory
        do_copy(location, context)
    end

    context
  end

  defp do_copy(erts_location, %Context{} = context) do
    # Clean out current bins
    dest_bin_path = Path.join(context.work_dir, ["erts-*/", "bin/"]) |> Path.wildcard() |> List.first()

    require IEx
    IEx.pry()

    File.rm_rf!(dest_bin_path)
    File.mkdir!(dest_bin_path)

    # Copy in new bins from unpacked ERTS
    unpacked_path = Path.join(erts_location, ["otp-*/", "erts-*/"]) |> Path.wildcard() |> List.first()
    src_bin_path = Path.join(unpacked_path, ["bin/"])

    File.cp_r!(src_bin_path, dest_bin_path)

    # The ERTS comes with some pre-built NIFs, so we need to replace those
    libs_to_replace = Path.join(context.work_dir, "lib/**/*.{so,dll}") |> Path.wildcard()
    src_lib_path = Path.join(erts_location, ["otp-*/", "lib/"]) |> Path.wildcard() |> List.first()
    dest_lib_path = Path.join(context.work_dir, ["lib/"])

    Enum.each(libs_to_replace, fn lib_file ->
      possible_src_path = String.replace(lib_file, dest_lib_path, src_lib_path)

      if File.exists?(possible_src_path) do
        File.rm!(lib_file)
        File.copy!(possible_src_path, lib_file)
        Logger.info("Replaced NIF #{lib_file} -> #{possible_src_path}")
      else
        File.rm!(lib_file)
        Logger.warn("We couldn't find a replacement for NIF #{lib_file}, the binary may not work!")
      end
    end)

    require IEx
    IEx.pry()
  end
end
