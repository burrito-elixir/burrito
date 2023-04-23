defmodule ExampleCliApp do
  def start(_, _args) do
    args = Burrito.Util.Args.get_arguments()

    IO.puts("My arguments are: #{inspect(args)}")
    IO.puts("'Random' number is #{1..999 |> Enum.random()} ... luck of the draw!!")

    System.halt(0)
  end
end
