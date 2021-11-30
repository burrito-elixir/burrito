defmodule Burrito.Util.FileCache do
  require Logger

  @cache_namespace "burrito_file_cache"

  @spec fetch(binary()) :: {:hit, binary} | :miss
  def fetch(key) when is_binary(key) do
    cache_dir = get_cache_dir()
    full_path = Path.join(cache_dir, [key])

    case File.read(full_path) do
      {:ok, data} -> {:hit, data}
      {:error, :enoent} -> :miss
    end
  end

  @spec put_if_not_exist(binary(), binary()) :: :ok
  def put_if_not_exist(key, data) do
    init_local_cache()

    cache_dir = get_cache_dir()
    full_path = Path.join(cache_dir, [key])

    if File.exists?(full_path) do
      :ok
    else
      Logger.info("Wrote new cache file: #{full_path}")
      File.write!(full_path, data, [:binary])
    end
  end

  @spec clear_cache() :: [binary()]
  def clear_cache do
    cache_dir = get_cache_dir()
    File.rm_rf!(cache_dir)
  end

  defp init_local_cache do
    get_cache_dir() |> File.mkdir_p!()
  end

  defp get_cache_dir do
    :filename.basedir(:user_cache, @cache_namespace) |> to_string()
  end
end
