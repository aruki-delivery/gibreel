defmodule Gibreel.Registry do
  @moduledoc false

  require Logger

  defp get_name(gibreel_agent) do
    {:via, Elixir.Registry, {Gibreel.Registry, gibreel_agent}}
  end

  def start_process(gibreel_agent) do
    Logger.info("#{__MODULE__}.start_process(#{inspect gibreel_agent})...")
    case Elixir.Registry.start_link(keys: :unique, name: Gibreel.Registry) do
      {:ok, res} ->
        case Agent.start_link(&Gibreel.empty_state/0, name: get_name(gibreel_agent)) do
          {:ok, res} -> {:ok, res}
          {:error, {:already_started, res}} ->
            Logger.info("#{__MODULE__}.start_process(#{inspect gibreel_agent}) ==== skipping #{inspect res}")
            {:ok, res}
        end
        {:ok, res}
      {:error, {:already_started, res}} ->
        Logger.info("#{__MODULE__}.start_process(#{inspect gibreel_agent})= skipping #{inspect res}")
        {:ok, res}
    end
  end

  def get(gibreel_agent) do
    rg = Agent.get(get_name(gibreel_agent), & &1)
    Logger.info("fetched agent: #{inspect rg}")
    rg
  end

  def start(gibreel_agent, config) do
    Logger.info("#{__MODULE__}.start(#{inspect gibreel_agent}, #{inspect config})...")
    case Agent.start_link(&Gibreel.empty_state/0, name: get_name(gibreel_agent)) do
      {:ok, res} -> {:ok, res}
      {:error, {:already_started, res}} ->
        Logger.info("#{__MODULE__}.start(#{inspect gibreel_agent}) = skipping #{inspect res}")
        {:ok, res}
    end
  end

  def start(gibreel_agent) do
    Logger.info("#{__MODULE__}.start(#{inspect gibreel_agent})...")
    case Agent.start_link(&Gibreel.empty_state/0, name: get_name(gibreel_agent)) do
      {:ok, res} -> {:ok, res}
      {:error, {:already_started, res}} ->
        Logger.info("#{__MODULE__}.start(#{inspect gibreel_agent}) = skipping #{inspect res}")
        {:ok, res}
    end
  end
end
