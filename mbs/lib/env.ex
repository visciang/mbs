defmodule MBS.Env do
  @moduledoc """
  Environment variable validator
  """

  alias MBS.Utils

  @spec validate :: :ok
  def validate do
    ["MBS_CACHE_VOLUME", "MBS_RELEASES_VOLUME", "MBS_GRAPH_VOLUME"]
    |> Enum.each(&exist_env/1)

    :ok
  end

  @spec exist_env(String.t()) :: :ok
  defp exist_env(env_name) do
    if System.get_env(env_name) == nil do
      Utils.halt("Environment variable #{env_name} not defined")
    else
      :ok
    end
  end
end
