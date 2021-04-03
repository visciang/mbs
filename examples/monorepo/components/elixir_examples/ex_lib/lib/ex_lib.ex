defmodule ExLib do
  def hello do
    {:hello_ex_lib, ExSubLib.hello()}
  end
end
