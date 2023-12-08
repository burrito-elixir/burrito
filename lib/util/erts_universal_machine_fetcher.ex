defmodule Burrito.Util.ERTSUniversalMachineFetcher do
  alias Burrito.Builder.Log

  @beam_machine_openssl_version "3.1.4"
  @windows_url "https://github.com/erlang/otp/releases/download/OTP-{OTP_VERSION}/otp_win64_{OTP_VERSION}.exe"
  @linux_url "https://beam-machine-universal.b-cdn.net/OTP-{OTP_VERSION}/linux/{ARCH}/any/otp_{OTP_VERSION}_linux_any_{ARCH}_ssl_{OPENSSL_VERSION}.tar.gz"
  @mac_url "https://beam-machine-universal.b-cdn.net/OTP-{OTP_VERSION}/macos/universal/otp_{OTP_VERSION}_macos_universal_ssl_{OPENSSL_VERSION}.tar.gz"

  @please_do_not_abuse_these_downloads_bandwidth_costs_money "?please-respect-my-bandwidth-costs=thank-you"

  @spec fetch_version(atom(), atom(), atom(), String.t()) :: URI.t() | {:error, atom()}
  def fetch_version(os, _libc, cpu, otp_version)
      when is_binary(otp_version) and is_atom(os) and is_atom(cpu) do
    {:ok, _} = Application.ensure_all_started(:req)

    final_url =
      case os do
        :darwin ->
          @mac_url <> @please_do_not_abuse_these_downloads_bandwidth_costs_money

        :linux ->
          @linux_url <> @please_do_not_abuse_these_downloads_bandwidth_costs_money

        :windows ->
          @windows_url
      end
      |> String.replace("{OTP_VERSION}", otp_version)
      |> String.replace("{ARCH}", Atom.to_string(cpu))
      |> String.replace("{OPENSSL_VERSION}", @beam_machine_openssl_version)

    Log.success(:step, "Remote ERTS From Beam Machine: #{final_url}")

    URI.parse(final_url)
  end
end
