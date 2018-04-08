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

    #######
    ### Functionality
    #######
    def create_cache(cacheName), do: create_cache(cacheName, [])
    def create_cache(cacheName, options) do
        case create_cache_config(options) do
            {:ok, config} -> GenServer.call(__MODULE__, {:create_cache, cacheName, config})
            {:error, reason} -> {:error, reason}
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
    def new_state, do: %State{pids: :dict.new()}
    def start_link([]) do
      Logger.info("#{__MODULE__}.start_link([])")
      Db.create()
      Agent.start_link(&new_state/0, name: __MODULE__)
    end

    @doc "Checks if the task has already executed"
    def executed?(task, project) do
      item = {task, project}
      Agent.get(__MODULE__, fn set ->
        item in set
      end)
    end

    #defp loop(state = %State{pids: pids}) do
    #  Logger.info("#{__MODULE__}.loop(#{inspect state}, pids=#{inspect pids})")
    #  Logger.info("looping state")
    #  send self(), state
    #end

    def handle_call({:create_cache, cacheName, cacheConfig}, _From, state=%State{pids: pids}) do
	    case Db.find(cacheName) do
            {:error, :no_cache} ->
                Db.store(%CacheRecord{name: cacheName, config: cacheConfig})
                {:ok, pid} = :g_cache_sup.start_cache(cacheName)
                :erlang.monitor(:process, pid)
                nPids = :dict.store(pid, cacheName, pids)
                {:reply, :ok, %State{pids: nPids}}
            {:ok, _} -> {:reply, {:error, :duplicated}, state}
        end
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
      Logger.info("#{__MODULE__} msg #{inspect wat}, #{msg}, #{inspect pid} #{inspect state}, pids=#{pids}")
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