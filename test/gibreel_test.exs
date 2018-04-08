defmodule GibreelTest do
  use ExUnit.Case, async: false


  test "creates a test agent registry cache" do
    {:ok, pid} = Gibreel.Registry.start(:test)
    created_state = Gibreel.create(pid, :test)
    assert created_state == %Gibreel.State{pids: {:dict, 0, 16, 16, 8, 80, 48, {[], [], [], [], [], [], [], [], [], [],
      [], [], [], [], [], []}, {{[], [], [], [], [], [], [], [], [], [], [], [], [], [], [], []}}}}
  end

  test "creates a agent test cache" do
    {:ok, pid} = Gibreel.start()
    cache = Gibreel.create(pid, :test)
    assert cache == %Gibreel.State{
             pids: {:dict, 0, 16, 16, 8, 80, 48,
               {[], [], [], [], [], [], [], [], [], [], [], [], [], [], [], []},
               {{[], [], [], [], [], [], [], [], [], [], [], [], [], [], [], []}}}
           }
  end

  test "creates a test cache" do
    {{:ok, pid}, cache} = Gibreel.create_cache(:test)
    assert cache == %Gibreel.State{
             pids: {:dict, 0, 16, 16, 8, 80, 48,
               {[], [], [], [], [], [], [], [], [], [], [], [], [], [], [], []},
               {{[], [], [], [], [], [], [], [], [], [], [], [], [], [], [], []}}}
           }
  end
end
