defmodule OnlyOne do
  alias OnlyOne.LockFile

  def start(_, _args) do
    # Create lockfile
    LockFile.make_lock_file()

    # Catch SIGINT
    Evac.setup(self())

    IO.puts("Running! Press ctrl-c to kill this program...")

    receive do
      'SIGINT' ->
        IO.puts("Killed!")
        LockFile.delete_lock_file()
    end

    # We're done!
    System.halt(0)
  end
end
