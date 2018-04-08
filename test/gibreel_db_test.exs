defmodule GibReelDbTest do
  use ExUnit.Case
  doctest Gibreel.Db

  test "greets the world" do
    assert Gibreel.Db.create() == :ok
    assert Gibreel.Db.create() == :ok
  end
end
