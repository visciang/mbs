defmodule MBS.Env do
  @moduledoc """
  Environment variable validator
  """

  alias MBS.Utils

  @spec validate :: :ok
  def validate do
    exist_env("MBS_PROJECT_ID")
    exist_env("MBS_TMP_VOLUME")
    exist_env("MBS_LOCAL_CACHE_VOLUME")
    exist_env("MBS_RELEASES_VOLUME")

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
