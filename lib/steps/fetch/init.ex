defmodule Burrito.Steps.Fetch.Init do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step
  alias Burrito.Builder.Log

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    work_dir = System.tmp_dir!() |> Path.join(["burrito_build_#{random_id}"])
    File.cp_r(context.mix_release.path, work_dir, fn _, _ -> true end)

    Log.info(:step, "Working directory: #{work_dir}")

    %Context{context | work_dir: work_dir}
  end
end
