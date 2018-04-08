defmodule Gibreel.CacheRecord do
  @moduledoc false
  @fields [name: "none", config: %Gibreel.CacheConfig{}]
  defstruct @fields
  def fields, do: @fields
end
