defmodule Gibreel do
  @moduledoc false

  require Logger

  ###############
  #### SWARM ####
  ###############

  @doc """
  Starts worker and registers name in the cluster, then joins the process
  to the `:gibreel` group
  """
  def start_worker(name) do
    {:ok, pid} = Swarm.register_name(name, Gibreel.Registry.Supervisor, :register, [name])
    Swarm.join(:gibreel, pid)
    {:ok, pid}
  end

  def create(cacheName) do
    Logger.info("#{__MODULE__}.create(#{cacheName})...")
    start_worker(cacheName)
  end

  @doc """
  Gets the pid of the worker with the given name
  """
  def whereis(name), do: Swarm.whereis_name(name)

  @doc """
  Gets all of the pids that are members of the `:gibreel` group
  """
  def get_workers(), do: Swarm.members(:gibreel)

  @doc """
  Call some worker by name
  """
  def call_worker(name, msg), do: GenServer.call({:via, :swarm, name}, msg)

  @doc """
  Cast to some worker by name
  """
  def cast_worker(name, msg), do: GenServer.cast({:via, :swarm, name}, msg)

  @doc """
  Publish a message to all members of group `:gibreel`
  """
  def publish_workers(msg), do: Swarm.publish(:gibreel, msg)

  @doc """
  Call all members of group `:foo` and collect the results,
  any failures or nil values are filtered out of the result list
  """
  def call_workers(msg), do: Swarm.multi_call(:gibreel, msg)


  #def delete_cache(cacheName), do: GenServer.cast(__MODULE__, {:delete_cache, cacheName})
  #def list_caches(), do: Gibreel.EtsManager.list_caches()
end