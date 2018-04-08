defmodule Gibreel.Db do
    require Logger

    def create() do
        check = :ets.info(:gibreel)
        Logger.info("#{__MODULE__}.create() check return = #{inspect check}")
        if :undefined == check do
          options = [:set, :public, :named_table, {:keypos, 2}, {:read_concurrency, true}]
          :ets.new(:gibreel, options)
          true = :ets.insert_new(:gibreel, {"__init___", :ok})
        else
          :ok = :ets.lookup(:gibreel, "__init___")
          Logger.info("#{__MODULE__}.create: skipping new ets")
        end
    end

    def drop(), do: :ets.delete(:gibreel)
    def find(cacheName) do
        case :ets.lookup(:gibreel, cacheName) do
            [record] -> {:ok, record}
            _ -> {:error, :no_cache}
        end
    end

    def store(record), do: :ets.insert(:gibreel, record)
    def delete(cacheName), do: :ets.delete(:gibreel, cacheName)

    def list_caches() do 
	    :ets.foldl(fn (%{name: cache}, acc) -> [cache|acc] end, [], :gibreel)
    end
end