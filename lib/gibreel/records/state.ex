defmodule Gibreel.State do
  @moduledoc false

  @fields [
    pids: []
  ]
  def fields, do: @fields
  defstruct @fields

  def empty() do
    %Gibreel.State{pids: :dict.new()}
  end
end
