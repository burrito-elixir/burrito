defmodule Burrito.Builder.Log do
  def info(type, message) do
    IO.puts(get_prefix(type) <> message)
  end

  def success(type, message) do
    IO.puts(:stderr, IO.ANSI.green() <> get_prefix(type) <> message <> IO.ANSI.reset())
  end

  def warning(type, message) do
    IO.puts(:stderr, IO.ANSI.yellow() <> get_prefix(type) <> message <> IO.ANSI.reset())
  end

  def error(type, message) do
    IO.puts(:stderr, IO.ANSI.red() <> get_prefix(type) <> message <> IO.ANSI.reset())
  end

  defp get_prefix(type) do
    case type do
      :build -> "> "
      :phase -> "----> "
      :step -> "--> "
    end
  end
end
