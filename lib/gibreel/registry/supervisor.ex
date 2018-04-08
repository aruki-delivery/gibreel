defmodule Gibreel.Registry.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor


  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Gibreel.Registry.Worker, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end


  def register(worker_name) do
    {:ok, _pid} = Supervisor.start_child(__MODULE__, [worker_name])
  end

end
