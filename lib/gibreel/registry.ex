defmodule Gibreel.Registry do
  @moduledoc false

  require Logger

  def start_process(gibreel_agent) do
    Logger.info("#{__MODULE__}.start_link([]) calling spawn(#{__MODULE__}, :start, [#{inspect gibreel_agent}])")
    res = spawn(__MODULE__, :start, [gibreel_agent])
    Logger.info("#{__MODULE__}.start_link([]) start_process(#{inspect gibreel_agent})")
    Logger.info("#{__MODULE__}.start_link([])=#{inspect res}")
    res
  end

  def get(gibreel_agent) do
    Logger.info("calling Agent.get(#{inspect gibreel_agent})")
    rg = Agent.get(gibreel_agent, &(&1))
    Logger.info("fetched agent: #{inspect rg}")
    rg
  end

  def start(agent) do
    state = %Gibreel.State{pids: :dict.new()}
    Logger.info("#{__MODULE__}.start(#{inspect agent}) with state=#{inspect state}")
    state
  end
end
