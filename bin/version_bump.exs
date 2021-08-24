#! elixir
defmodule VersionBump do
  def bump_major(%Version{} = ver) do
    %Version{ver | major: ver.major + 1, minor: 0, patch: 0}
  end

  def bump_minor(%Version{} = ver) do
    %Version{ver | minor: ver.minor + 1, patch: 0}
  end

  def bump_patch(%Version{} = ver) do
    %Version{ver | patch: ver.patch + 1}
  end
end

version_file = "./VERSION"

current_version =
  String.trim(File.read!(version_file))
  |> Version.parse!()

bump_type = System.argv() |> List.first()

new_version =
  case bump_type do
    "major" -> VersionBump.bump_major(current_version)
    "minor" -> VersionBump.bump_minor(current_version)
    "patch" -> VersionBump.bump_patch(current_version)
  end

commit_message = "Bumped version from #{current_version} -> #{new_version}"
IO.puts(commit_message)

File.write!(version_file, to_string(new_version))
{_, 0} = System.cmd("git", ["add", version_file])
{_, 0} = System.cmd("git", ["commit", "-m", commit_message])
