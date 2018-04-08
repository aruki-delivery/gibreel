defmodule Gibreel.Application do
  @moduledoc false
  use Application

  require Logger

  def start(_type, _args) do
    Logger.info("#{__MODULE__}.start(_type, _args)")
    {:ok, super_pid} = Supervisor.start_link([Gibreel], strategy: :one_for_one)
    # Logic
    {:ok, super_pid}
  end

end
