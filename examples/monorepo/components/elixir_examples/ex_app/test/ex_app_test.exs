defmodule ExAppTest do
  use ExUnit.Case

  test "hello -> ex_lib -> ex_sublib" do
    assert ExApp.hello() == {:hello, {:hello_ex_lib, :hello_ex_sublib}}
  end
end
