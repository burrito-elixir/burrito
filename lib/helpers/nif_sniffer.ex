defmodule Burrito.Helpers.NIFSniffer do
  def find_nifs() do
    # The current procedure for finding out if a dependency has a NIF:
    # - List all deps in the project using Mix.Project.deps_paths/0
    #   - Iterate over those, and use Mix.Project.in_project/4 to execute a function inside their project context
    #   - Check if they contain :elixir_make in their `:compilers`
    #
    # We'll probably need to expand how we detect NIFs, but :elixir_make is a popular way to compile NIFs
    # so it's a good place to start...

    paths = Mix.Project.deps_paths() |> Enum.filter(fn {name, _} -> name != :burrito end)

    Enum.map(paths, fn {dep_name, path} ->
      Mix.Project.in_project(dep_name, path, fn module -> 
        if module && Keyword.has_key?(module.project, :compilers) do
          {dep_name, path, Enum.member?(module.project[:compilers], :elixir_make)}
        else
          {dep_name, path, false}
        end
      end)
    end)
  end
end