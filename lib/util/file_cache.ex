defmodule Burrito.Util.FileCache do
  require Logger

  @cache_namespace "burrito_file_cache"

  @spec fetch(binary()) :: {:hit, binary} | {:error, term()} | :miss
  def fetch(key) when is_binary(key) do
    cache_dir = get_cache_dir()
    full_path = Path.join(cache_dir, [key])

    case File.read(full_path) do
      {:ok, data} -> {:hit, data}
      {:error, :enoent} -> :miss
    end
  rescue
    err -> {:error, err}
  end

  @spec put_if_not_exist(binary(), binary()) :: :ok | {:error, term()}
  def put_if_not_exist(key, data) do
    cache_dir = get_cache_dir()
    full_path = Path.join(cache_dir, [key])

    if File.exists?(full_path) do
      :ok
    else
      Logger.info("Wrote new cache file: #{full_path}")
      File.write!(full_path, data, [:binary])
    end
  end

  @spec clear_cache() :: :ok | {:error, term()}
  def clear_cache do
    cache_dir = get_cache_dir()
    File.rm_rf!(cache_dir)
    :ok
  rescue
    err -> {:error, err}
  end

  defp get_cache_dir do
    dir = :filename.basedir(:user_cache, @cache_namespace) |> to_string()

    case File.mkdir_p(dir) do
      :ok ->
        dir

      {:error, err} ->
        Logger.error("Failed to access cache directory")
        raise "Could not access the Burrito cache directory (#{err})"
    end
  end
end
