defmodule SteamexTest do
  use ExUnit.Case
  doctest Steamex

  test "greets the world" do
    assert Steamex.hello() == :world
  end
end
