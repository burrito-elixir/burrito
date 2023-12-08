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
end
