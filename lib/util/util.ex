defmodule Burrito.Util do
  @spec get_current_os :: :darwin | :linux | :windows
  def get_current_os do
    case :os.type() do
      {:win32, _} -> :windows
      {:unix, :darwin} -> :darwin
      {:unix, :linux} -> :linux
    end
  end

  def get_current_cpu do
    arch_string =
      :erlang.system_info(:system_architecture)
      |> to_string()
      |> String.downcase()
      |> String.split("-")
      |> List.first()

    case arch_string do
      "x86_64" -> :x86_64
      "arm64" -> :aarch64
      "aarch64" -> :aarch64
      _ -> :unknown
    end
  end

  @spec get_otp_version :: String.t()
  def get_otp_version() do
    {:ok, otp_version} =
      :file.read_file(
        :filename.join([
          :code.root_dir(),
          "releases",
          :erlang.system_info(:otp_release),
          "OTP_VERSION"
        ])
      )

    String.trim(otp_version)
  end

  @doc """
  Checks if the application is currently running as a standalone Burrito release, or via some other mechanism,
  such as an `escript`.
  """
  @spec running_standalone?() :: boolean()
  def running_standalone?() do
    System.get_env("__BURRITO") != nil
  end

  @doc """
  Gets the HTTP or HTTPS proxy from environment variables, if set.
  1. Checks `HTTP_PROXY` and `http_proxy`
  2. Checks `HTTPS_PROXY` and `https_proxy`
  3. Returns `nil` if no proxy is set
  """
  @spec get_proxy :: URI.t() | nil
  def get_proxy do
    cond do
      proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy") ->
        URI.parse(proxy)

      proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") ->
        URI.parse(proxy)

      true ->
        nil
    end
  end
end
