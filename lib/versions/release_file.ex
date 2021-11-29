defmodule Burrito.Versions.ReleaseFile do
  @moduledoc """
  This module provides some helpful functions for requesting, parsing and sorting release files.
  A release file is a simplistic JSON format that contains the releases of an app, where to fetch them, and some release notes.
  (And any other information you want to store in there!)

  Example Release File:

  ```json
  {
    "app_name": "example_cli_app",
    "releases": [
      {
        "version": "0.2.0",
        "notes": "This new version is new and exciting, we promise!",
        "urls": {
          "win64": "https://example.com/releases/0.2.0/example_cli_app_win64.exe",
          "darwin": "https://example.com/releases/0.2.0/example_cli_app_linux",
          "linux": "https://example.com/releases/0.2.0/example_cli_app_darwin"
        }
      },
      {
        "version": "0.1.5",
        "notes": "This new version is new and exciting, we promise!",
        "urls": {
          "win64": "https://example.com/releases/0.1.5/example_cli_app_win64.exe",
          "darwin": "https://example.com/releases/0.1.5/example_cli_app_linux",
          "linux": "https://example.com/releases/0.1.5/example_cli_app_darwin"
        }
      }
    ]
  }
  ```

  The only required parts of a release JSON file is:
    * `"app_name"` and `"releases"` keys must be present at the top-level object
    * `"releases"` must be a list of objects that have a `"version"` key that contains a semver string

  Here's the minimal JSON Schema for a release file:

  ```json
  {
    "$schema": "http://json-schema.org/draft-07/schema",
    "required": [
      "app_name",
      "releases"
    ],
    "type": "object",
    "properties": {
      "app_name": {
        "type": "string"
      },
      "releases": {
        "type": "array",
        "additionalItems": true,
        "items": {
          "anyOf": [
            {
              "default": {},
              "required": [
                "version"
              ],
              "type": "object",
              "properties": {
                "version": {
                  "title": "The version schema",
                  "type": "string"
                }
              },
              "additionalProperties": true
            }
          ]
        }
      }
    },
    "additionalProperties": true
  }
  ```

  You can customize everything else to your liking!

  To use the functions in this module, you simply upload this to some HTTP server, and call

  ```elixir
  {:ok, release_map} = fetch_releases_from_url(release_url)
  maybe_new_release = get_new_version(release_map, current_semver_version_string)
  ```

  Which will return either the release map data of a newer release, or `nil` if there is no newer release.
  """

  def fetch_releases_from_url(url, req_options \\ []) when is_binary(url) do
    Req.get!(url, req_options).body
  end

  @spec get_new_version(map(), String.t()) :: map() | nil
  def get_new_version(release_map, current_version_string) do
    with {:ok, curr_version} <- Version.parse(current_version_string),
         %{} = newer_version <- find_newer_version(curr_version, release_map) do
      newer_version
    else
      _ -> nil
    end
  end

  defp find_newer_version(%Version{} = curr_version, release_map) do
    releases = Map.get(release_map, "releases", [])

    newer_release =
      Enum.filter(releases, fn release ->
        this_version = Map.get(release, "version", "0.0.0") |> Version.parse!()
        Version.compare(curr_version, this_version) == :lt
      end)
      |> Enum.sort_by(& &1["version"], {:desc, Version})
      |> List.first()

    newer_release
  end
end
