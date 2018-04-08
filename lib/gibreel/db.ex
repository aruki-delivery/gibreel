defmodule Gibreel.Db do
    def create() do
        options = [:set, :public, :named_table, {:keypos, 2}, {:read_concurrency, true}]
        :ets.new(:gibreel, options)
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