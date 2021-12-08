defmodule Burrito.Builder do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Target
  alias Burrito.Steps.Fetch

  require Logger

  @moduledoc """
  Burrito builds in "phases". Each phase contains any number of "steps" which are executed one after another.

  There are 4 phases:

  `:fetch` - This phase is responsible for downloading or copying in any replacement ERTS builds for cross-build targets.
  `:patch` - The patch phase injects custom scripts into the build directory, this phase is also where any custom files should be copied into the build directory before being archived.
  `:archive` - Once the archive phase is finished, all files in the release build directory will be packaged into a foilz archive.
  `:build` - This is the final phase in the build flow, it produces the final wrapper binary with the payload embedded inside.

  You can add your own steps before and after phases execute. Your custom steps will also receive the build context struct, and can return a modified one to customize a build to your liking.

  An example of added a step before the fetch phase, and after the build phase:

  ```
  # ... mix.exs file
  def releases do
    [
      my_app: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          # ... other Burrito configuration
          steps: [
            {:pre, :fetch, MyCustomStepModule},
            {:post, :build, AnotherCustomStepModule}
          ]
        ]
      ]
    ]
  end
  # ...
  ```
  """

  @phases [
    fetch: [Fetch.InitBuild, Fetch.FetchERTS],
    patch: [],
    archive: [],
    build: []
  ]

  def build(%Mix.Release{} = release) do
    options = release.options[:burrito] || []
    debug? = Keyword.get(options, :debug, false)

    # TODO: make this loop over targets instead of picking the first one
    # this is currently for debugging reasons!
    build_target = options[:targets] |> List.first()

    target = Target.init_target(build_target, debug?)
    self_path =
      __ENV__.file
      |> Path.dirname()
      |> Path.split() # current directory: (burrito/lib/build/)
      |> List.delete_at(-1) # ../
      |> List.delete_at(-1) # ../
      |> Path.join() # result directory: burrito/

    initial_context = %Context{
      target: target,
      erts_location: :local,
      cross_build: false,
      mix_release: release,
      work_dir: self_path,
      warnings: [],
      errors: [],
      halt: false
    }

    Logger.info("Burrito will build for target:\n\tOS: #{target.os}\n\tCPU: #{target.cpu}\n\tLibC: #{target.libc}\n\tDebug: #{target.debug?}")

    Enum.reduce(@phases, initial_context, &run_phase/2)
  end

  defp run_phase({phase_name, mod_list}, %Context{} = context) do
    # TODO: check for pre-phase steps
    Logger.info("> PHASE: #{inspect(phase_name)}")
    Enum.reduce(mod_list, context, fn mod, %Context{} = acc ->
      Logger.info("\t> STEP: #{inspect(mod)}")
      %Context{} = new_context = mod.execute(acc)

      # Print errors or warnings
      Enum.each(new_context.warnings, &warn/1)
      Enum.each(new_context.errors, &error/1)

      # Halt if `halt` flag was set
      if new_context.halt do
        Logger.error("Halt requested from phase: #{inspect(phase_name)} in step #{inspect(mod)}")
        exit(1)
      end

      # reset errors and warnings
      %Context{new_context | warnings: [], errors: []}
    end)
    # TODO: check for post-phase steps
  end

  defp warn(message) do
    Logger.warn("\t> " <> message)
  end

  defp error(message) do
    Logger.error("\t> " <> message)
  end
end
