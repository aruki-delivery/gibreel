defmodule Gibreel.CacheConfig do
  @moduledoc false

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

  def create(options) do
    expire   = :proplists.get_value(:max_age,            options, 0)
    function = :proplists.get_value(:get_value_function, options, :none)
    maxSize  = :proplists.get_value(:max_size,           options, :none)
    nodes    = :proplists.get_value(:cluster_nodes,      options, :local)
    purge    = :proplists.get_value(:purge_interval,     options, :none)
    sync     = :proplists.get_value(:sync_mode,          options, :lazy)

    if validate_max_age(expire) == :ok &&
        validate_function(function) == :ok &&
        validate_max_size(maxSize) == :ok &&
        validate_nodes(nodes) == :ok &&
        validate_purge_interval(purge, expire) == :ok &&
        validate_sync_mode(sync) == :ok
      do
      {:ok, %Gibreel.CacheConfig{
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

  def fetch_config(cacheName) do
    case Gibreel.EtsManager.find(cacheName) do
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
end
