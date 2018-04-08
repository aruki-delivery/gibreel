defmodule Gibreel do
    @moduledoc false

    use Agent, restart: :permanent
    require Logger

    alias Gibreel.Db, as: Db

    #######
    #Records
    #######
    defmodule CacheConfig do
      @fields [
        max_age: 0, #no max age
        get_value_function: :none, # idempotent
        max_size: :none,  #no max size
        purge_interval: :none, #no purge
        sync_mode: :lazy, # :lazy or :full
        cluster_nodes: :local # :local or :all
      ]
      def fields, do: @fields
      defstruct @fields
    end

    defmodule CacheRecord do
      @fields [name: "none", config: %CacheConfig{}]
      def fields, do: @fields
      defstruct @fields
    end

    defmodule State do
      @fields [
        pids: []
      ]
      def fields, do: @fields
      defstruct @fields
    end

    def empty_state(), do: %State{pids: :dict.new()}

    #######
    ### Functionality
    #######
    def create(pid, cacheName) do
        Logger.info("#{__MODULE__}.create(#{inspect pid}, #{cacheName})...")
        pid |>
          Agent.get_and_update(fn (state) ->
            #Logger.info("got state for cacheName=#{cacheName} #{inspect state}")
            case state do
              %Gibreel.State{pids: []} ->
                #Logger.info("cacheName=#{cacheName} got empty state")
                {empty_state(), empty_state()}
              non_empty = %Gibreel.State{} ->
                #Logger.info("cacheName=#{cacheName} got non-empty state")
                {non_empty, non_empty}
              pid when is_pid(pid) ->
                  if Process.alive?(pid) do
                    #Logger.info("cacheName=#{cacheName} got pid #{inspect pid} for alive proc")
                    {state, Agent.get(pid, fn s -> s end)}
                  else
                    #Logger.warn("cacheName=#{cacheName} got pid #{inspect pid} for dead proc")
                    state = Gibreel.Registry.start(cacheName)
                    {:ok, pid} = Gibreel.start()
                    {state, Agent.get(pid, fn (s) -> {s, state} end)}
                  end
            end
          end)
    end
    
    def create_cache(cacheName) do
      Logger.info("#{__MODULE__}.create_cache(#{cacheName})")
      create_cache(cacheName, [])
    end
    def create_cache(cacheName, options) do
        Logger.info("#{__MODULE__}.create_cache(#{cacheName}, #{inspect options})")
        case create_cache_config(options) do
            {:ok, config} ->
              #Logger.info("Calling GenServer for (#{cacheName}, #{inspect(config)}")
              #GenServer.call(__MODULE__, {:create_cache, cacheName, config})
              state = Gibreel.Registry.start(cacheName, config)
              Logger.info("Registry state=#{inspect state}")
              {:ok, pid} = Gibreel.start()
              {state, Agent.get(pid, fn (s) -> {s, state} end)}
            {:error, reason} ->
              {:error, reason}
        end
    end

    defp create_cache_config(options) do
        expire   = :proplists.get_value(:max_age,            options, 0)
        function = :proplists.get_value(:get_value_function, options, :none)
        maxSize  = :proplists.get_value(:max_size,           options, :none)
        nodes    = :proplists.get_value(:cluster_nodes,      options, :local)
        purge    = :proplists.get_value(:purge_interval,     options, :none)
        sync     = :proplists.get_value(:sync_mode,          options, :lazy)

        if validate_max_age(expire) == :ok && validate_function(function) == :ok && \
            validate_max_size(maxSize) == :ok && validate_nodes(nodes) && \
            validate_purge_interval(purge, expire) == :ok && validate_sync_mode(sync) == :ok
        do
            {:ok, %CacheConfig{
                max_age: expire,
                purge_interval: purge,
                get_value_function: function,
                max_size: maxSize,
                cluster_nodes: nodes,
                sync_mode: sync}
            }
        else
            {:error, :invalid_options} 
        end
    end

    def delete_cache(cacheName), do: GenServer.cast(__MODULE__, {:delete_cache, cacheName})
    def list_caches(), do: Db.list_caches()
    
    def cache_config(cacheName) do
        case Db.find(cacheName) do
            {:ok, cache_record} ->
                [
                    {:max_age,            cache_record[:config][:cache_config].max_age},
                    {:get_value_function, cache_record[:config][:cache_config].get_value_function},
                    {:max_size,           cache_record[:config][:cache_config].max_size},
                    {:cluster_nodes,      cache_record[:config][:cache_config].cluster_nodes},
                    {:purge_interval,     cache_record[:config][:cache_config].purge_interval},
                    {:sync_mode,          cache_record[:config][:cache_config].sync_mode}
                ]
            {:error, no_cache} -> no_cache
        end
    end

    ########
    #Supervisor / OTP
    ########

    def init(state) do
      {:ok, state}
    end

    def start(), do: start_link([])

    def start_link([]) do
      :ok = Db.create()
      Logger.info("#{__MODULE__}.start_link Db is ready")
      {:ok, pid} = Agent.start_link(fn -> Gibreel.Registry.start_process(__MODULE__) end)
      Logger.info("#{__MODULE__}.start_link Gibreel.Registry started #{__MODULE__} on pid=#{inspect pid}")
      res = Agent.start_link(fn -> Gibreel.Registry.start_process(Gibreel.Registry) end)
      Logger.info("#{__MODULE__}.start_link started registry #{inspect res}")
      GenServer.start_link(__MODULE__, %{})
    end

    @doc "Checks if the task has already executed"
    def executed?(task, project) do
      Logger.info("#{__MODULE__}.executed?(#{inspect task}, #{inspect project})")
      item = {task, project}
      agent = Gibreel.Registry.get(__MODULE__)
      state = Agent.get_and_update(agent, fn set ->
        item in set
      end)
      Logger.info("#{__MODULE__}.executed?(#{inspect task}, #{inspect project}=#{inspect state}")
      state
    end

    #defp loop(state = %State{pids: pids}) do
    #  Logger.info("#{__MODULE__}.loop(#{inspect state}, pids=#{inspect pids})")
    #  Logger.info("looping state")
    #  send self(), state
    #end


    def handle_call({:create_cache, cacheName, cacheConfig}, from, state=%State{pids: pids}) do
      Logger.info("non_empty create_cache from=#{inspect from}")
      Logger.info("non_empty create_cache state=#{inspect state}")
	    case Db.find(cacheName) do
        {:error, :no_cache} ->
            Db.store(%CacheRecord{name: cacheName, config: cacheConfig})
            {:ok, pid} = :g_cache_sup.start_cache(cacheName)
            :erlang.monitor(:process, pid)
            nPids = :dict.store(pid, cacheName, pids)
            {:reply, :ok, %State{pids: nPids}}
        {:ok, _} ->
          {:reply, {:error, :duplicated}, state}
      end
    end


    def handle_call({:create_cache, cacheName, cacheConfig}, from, state) do
      Logger.info("create_cache from=#{inspect from}")
      Logger.info("create_cache state=#{inspect state}")
      case Db.find(cacheName) do
        {:error, :no_cache} ->
          Logger.info("cache miss for #{cacheName}")
          Db.store(%CacheRecord{name: cacheName, config: cacheConfig})
          {:ok, pid} = :g_cache_sup.start_cache(cacheName)
          :erlang.monitor(:process, pid)
          nPids = :dict.store(pid, cacheName, state)
          {:reply, :ok, %State{pids: nPids}}
        {:ok, _} -> {:reply, {:error, :duplicated}, :dict.new()}
      end
    end


    def handle_call({:get_and_update, func}, _from, %{}) do
      Logger.info("handle_call_get_and_update")
      {:ok, pid} = Gibreel.Registry.start(Gibreel)
      state = Agent.get(pid, & &1)
      Logger.info("handle_call_get_and_update prev_state=#{inspect state}")
      new_state = func.(state)
      Logger.info("handle_call_get_and_update new_state=#{inspect new_state}")
      {:reply, state, new_state}
    end

    def handle_call({:get, func}, _from, %{}) do
      Logger.info("handle_call_get")
      {:ok, pid} = Gibreel.Registry.start(Gibreel)
      state = Agent.get(pid, & &1)
      Logger.info("handle_call_get=#{inspect state}")
      new_state = func.(state)
      r = {:reply, state, new_state}
      Logger.info("handle_call_get_res=#{inspect r}")
      r
    end

    def handle_call({:update, func}, _from, %{}) do
      Logger.info("handle_call update")
      state = Gibreel.Registry.start(Gibreel)
      Logger.info("handle_call update prev_state=#{inspect state}")
      new_state = func.(state)
      Logger.info("handle_call update new_state=#{inspect new_state}")
      {:reply, new_state, new_state}
    end


    def handle_call(msg, from, state) do
      Logger.info("#{__MODULE__}.handle_call: wat unknown call: #{inspect msg} from=#{inspect from} and state=#{inspect(state)}")
      {:reply, :unknown_call, state}
    end

    def handle_cast({:delete_cache, cacheName}, state=%State{pids: pids}) do
	    case Process.whereis(cacheName) do
		    :undefined -> {:noreply, state}
		    pid -> 
			    send(pid,{:stop_cache})
			    Db.delete(cacheName)
			    nPids = :dict.erase(pid, pids)
                {:noreply, %State{pids: nPids}}
        end
	  end

    def handle_info({'DOWN', _MonitorRef, :process, pid, :shutdown}, state=%State{pids: pids}) do
        case :dict.find(pid, pids) do
            :error -> {:noreply, state}
            {:ok, cacheName} ->
                Db.delete(cacheName)
                dPids = :dict.erase(pid, pids)
                {:noreply, %State{pids: dPids}}
        end
    end

    def handle_info({'DOWN', _MonitorRef, :process, pid, _Reason}, state=%State{pids: pids}) do
        case :dict.find(pid, pids) do
            :error -> {:noreply, state}
            {:ok, cacheName} ->
                dPids = :dict.erase(pid, pids)
                {:ok, nPid} = :g_cache_sup.start_cache(cacheName)
                nPids = :dict.store(nPid, cacheName, dPids)
                {:noreply, %State{pids: nPids}}
        end
    end

    def handle_info(wat = {msg, _MonitorRef, process: pid}, state=%State{pids: pids}) do
      Logger.info("#{__MODULE__} wat msg #{inspect wat}, #{msg}, #{inspect pid} #{inspect state}, pids=#{pids}")
    end

    def terminate(_Reason, _State) do
        Db.drop()
        :ok
    end
	
    def code_change(_OldVsn, state, _Extra), do: {:ok, state}


    defp validate_max_age(expire) when is_integer(expire), do: :ok
    defp validate_max_age(_), do: "Max-Age must be an integer (seconds)"

    defp validate_function(:none), do: :ok
    defp validate_function(function) when is_function(function, 1), do: :ok
    defp validate_function(_Function), do: "Get-Value-Function must be one function with arity 1"

    defp validate_max_size(:none), do: :ok
    defp validate_max_size(maxSize) when is_integer(maxSize) and maxSize > 0, do: :ok
    defp validate_max_size(_), do: "Max-Size must be an integer and bigger than zero"

    defp validate_nodes(:local), do: :ok
    defp validate_nodes(:all), do: :ok
    defp validate_nodes([]), do: "Empty list is not valid for Cluster-Nodes"
    defp validate_nodes(nodes) when is_list(nodes) do
      case Enum.filter(nodes, &is_atom/1) do
        [] -> :ok
        _ -> "Cluster-Nodes must be a list of nodes or the values local or all"
      end
    end

    defp validate_nodes(_), do: "Cluster-Nodes must be a list of nodes or the values local or all"

    defp validate_purge_interval(:none, _Expire), do: :ok
    defp validate_purge_interval(_Purge, :none), do: "To use Purge-Interval you must use Max-Age"
    defp validate_purge_interval(purge, _Expire) when is_integer(purge) and purge > 0, do: :ok
    defp validate_purge_interval(_Purge, _Expire), do: "Purge-Interval must be an integer and bigger than zero
    (seconds)"

    defp validate_sync_mode(:lazy), do: :ok
    defp validate_sync_mode(:full), do: :ok
    defp validate_sync_mode(_Sync), do: "Sync-Mode must be lazy ou full"
end