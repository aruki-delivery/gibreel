defmodule Gibreel.Registry.Worker do
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, [name])
  end

  def init([name]) do
    {:ok, {name, Map.new()}, 0}
  end


  ############
  # Calls
  ############


  # called when a handoff has been initiated due to changes
  # in cluster topology, valid response values are:
  #
  #   - `:restart`, to simply restart the process on the new node
  #   - `{:resume, state}`, to hand off some state to the new process
  #   - `:ignore`, to leave the process running on its current node
  #
  def handle_call({:swarm, :begin_handoff}, _from, {name, delay}) do
    {:reply, {:resume, delay}, {name, delay}}
  end


  def handle_call({:create_cache, cacheName, cacheConfig}, _from, state) do
    Logger.info("handle_create_cache(#{inspect cacheName}, #{inspect cacheConfig}, #{inspect state}")
    case Gibreel.whereis(cacheName) do
      :undefined ->
        Logger.info("handle_create_cache(#{inspect cacheName}, creating new worker")
        {:ok, pid} = Gibreel.create(cacheName)
        pid
      pid ->
        Logger.info("handle_create_cache(#{inspect cacheName}, found existing worker")
        pid
    end
  end


  def handle_call({:get_and_update, cacheName, func}, _from, _state) do
    Logger.info("handle_call_get_and_update")
    pid = case Gibreel.whereis(cacheName) do
      :undefined ->
        Logger.info("handle_call_get_and_update(#{inspect cacheName}, creating new worker")
        {:ok, pid} = Gibreel.create(cacheName)
        pid
      pid ->
        Logger.info("handle_create_cache(#{inspect cacheName}, found existing worker")
        pid
    end

    Logger.info("handle_call_get_and_update prev_state=#{inspect state}")
    new_state = func.(state)
    Logger.info("handle_call_get_and_update new_state=#{inspect new_state}")
    {:reply, state, new_state}
  end

  def handle_call({:get, cacheName, func}, _from, _state) do
    Logger.info("handle_call_get")
    case Gibreel.whereis(cacheName) do
      :undefined ->
        Logger.info("handle_get(#{inspect cacheName}, found existing worker")
        func.(:undefined)

      pid ->
        Logger.info("handle_get(#{inspect cacheName}, found existing worker")
        pid
    end
    new_state = func.(state)
    r = {:reply, state, new_state}
    Logger.info("handle_call_get_res=#{inspect r}")
    r
  end


  def handle_call({:update, func}, _from, _state) do
    Logger.info("handle_call update")
    state = Gibreel.Registry.start_link(Gibreel)
    Logger.info("handle_call update prev_state=#{inspect state}")
    new_state = func.(state)
    Logger.info("handle_call update new_state=#{inspect new_state}")
    {:reply, new_state, new_state}
  end

  def handle_call(msg, from, state) do
    Logger.error("#{__MODULE__}.handle_call: wat unknown call: #{inspect msg} from=#{inspect from} and
      state=#{inspect(state)}")
    {:reply, :unknown_call, state}
  end

  def handle_info(wat = {msg, _MonitorRef, process: pid}, state=%Gibreel.State{pids: pids}) do
    Logger.error("#{__MODULE__} wat msg #{inspect wat}, #{msg}, #{inspect pid} #{inspect state}, pids=#{pids}")
    {:stop, :bad_arg}
  end

  # this message is sent when this process should die
  # because it is being moved, use this as an opportunity
  # to clean up
  def handle_info({:swarm, :die}, state) do
    {:stop, :shutdown, state}
  end

  # called after the process has been restarted on its new node,
  # and the old process' state is being handed off. This is only
  # sent if the return to `begin_handoff` was `{:resume, state}`.
  # **NOTE**: This is called *after* the process is successfully started,
  # so make sure to design your processes around this caveat if you
  # wish to hand off state like this.
  def handle_cast({:swarm, :end_handoff, delay}, {name, _}) do
    {:noreply, {name, delay}}
  end

  # called when a network split is healed and the local process
  # should continue running, but a duplicate process on the other
  # side of the split is handing off its state to us. You can choose
  # to ignore the handoff state, or apply your own conflict resolution
  # strategy
  def handle_cast({:swarm, :resolve_conflict, _delay}, state) do
    {:noreply, state}
  end

  def handle_cast({:delete_cache, cacheName}, state) do
    case Gibreel.whereis(cacheName) do
      :undefined -> {:noreply, state}
      pid ->
        Logger.info("handle_cast_delete: found worker at #{inspect pid}")
        {:noreply, %Gibreel.State{pids: []}}
    end
  end

end
