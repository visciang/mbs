defmodule MBS.Config.Data do
  @moduledoc false

  defmodule Cache do
    @moduledoc false
    defstruct [:dir]
  end

  defstruct [:root_dir, :parallelism, :cache, :timeout]
end

defmodule MBS.Config do
  @moduledoc """
  Global config
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
        conf = to_struct(conf)
        put_in(conf.root_dir, mbs_root_dir())

      {:error, reason} ->
        Utils.halt("Error parsing configuration file #{@config_file}\n  #{Jason.DecodeError.message(reason)}")
    end
  end

  defp to_struct(conf) do
    default_parallelism = :erlang.system_info(:logical_processors)

    %Data{
      parallelism: conf |> Map.get("parallelism", default_parallelism),
      cache: %Data.Cache{
        dir: conf |> Map.fetch!("cache") |> Map.fetch!("dir") |> Path.expand()
      },
      timeout: conf |> Map.get("timeout", :infinity)
    }
  end

  defp mbs_root_dir do
    case System.get_env("MBS_ROOT") do
      nil ->
        Utils.halt("Missing MBS_ROOT environment variable")

      root_dir ->
        root_dir
    end
  end
end
