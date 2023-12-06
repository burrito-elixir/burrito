defmodule Burrito.Util.ERTSBeamMachineFetcher do
  alias Burrito.Builder.Log

  @beam_machine_openssl_version "1.1.1s"
  @windows_url "https://github.com/erlang/otp/releases/download/OTP-{OTP_VERSION}/otp_win64_{OTP_VERSION}.exe"
  @linux_url "https://burrito-otp.b-cdn.net/OTP-{OTP_VERSION}/linux/{ARCH}/{LIBC}/otp_{OTP_VERSION}_linux_{LIBC}_{ARCH}_ssl_{OPENSSL_VERSION}.tar.gz"
  @mac_url "https://burrito-otp.b-cdn.net/OTP-{OTP_VERSION}/darwin/{ARCH}/otp_{OTP_VERSION}_darwin_{ARCH}_ssl_{OPENSSL_VERSION}.tar.gz"

  @please_do_not_abuse_these_downloads_bandwidth_costs_money "?please-respect-my-bandwidth-costs=thank-you"

  @spec fetch_version(atom(), atom(), atom(), String.t()) :: URI.t() | {:error, atom()}
  def fetch_version(os, libc, cpu, otp_version)
      when is_binary(otp_version) and is_atom(os) and is_atom(cpu) and is_atom(libc) do
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
      |> String.replace("{LIBC}", Atom.to_string(libc))
      |> String.replace("{OPENSSL_VERSION}", @beam_machine_openssl_version)

    Log.success(:step, "Remote ERTS From Beam Machine: #{final_url}")

    URI.parse(final_url)
  end
end
