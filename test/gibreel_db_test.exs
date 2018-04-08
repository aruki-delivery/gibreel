defmodule GibReelDbTest do
  use ExUnit.Case
  doctest Gibreel.Db

  test "handles multiple db creations" do
    assert Gibreel.Db.create() == :ok
    assert Gibreel.Db.create() == :ok
  end
end
