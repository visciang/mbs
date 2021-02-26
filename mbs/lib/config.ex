defmodule MBS.Config.Data do
  @moduledoc false

  defmodule Cache do
    @moduledoc false
    defstruct [:directory]
  end

  defstruct [:parallelism, :cache]
end

defmodule MBS.Config do
  @moduledoc """
  Application config
  """
  require Logger

  alias MBS.Config.Data
  alias MBS.Utils

  @config_file ".mbs-config.json"

  def load do
    case File.read(@config_file) do
      {:ok, conf_data} ->
        parse(conf_data)

      {:error, reason} ->
        Utils.halt("Cannot read configuration file #{@config_file} (#{reason})")
    end
  end

  defp parse(conf_data) do
    case Jason.decode(conf_data) do
      {:ok, conf} ->
        to_struct(conf)

      {:error, reason} ->
        Utils.halt("Error parsing configuration file #{@config_file}\n  #{Jason.DecodeError.message(reason)}")
    end
  end

  defp to_struct(conf) do
    default_parallelism = :erlang.system_info(:logical_processors)

    %Data{
      parallelism: conf |> Map.get("parallelism", default_parallelism),
      cache: %Data.Cache{
        directory: conf |> Map.fetch!("cache") |> Map.fetch!("directory") |> Path.expand()
      }
    }
  end
end
