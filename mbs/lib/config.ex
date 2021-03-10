defmodule MBS.Config.Data do
  @moduledoc false

  defmodule Cache do
    @moduledoc false
    defstruct [:dir]

    @type t :: %__MODULE__{
            dir: Path.t()
          }
  end

  defstruct [:root_dir, :parallelism, :cache, :timeout]

  @type t :: %__MODULE__{
          root_dir: Path.t(),
          parallelism: non_neg_integer(),
          cache: %Cache{},
          timeout: timeout()
        }
end

defmodule MBS.Config do
  @moduledoc """
  Global config
  """
  require Logger

  alias MBS.Config.Data
  alias MBS.Utils

  @config_file ".mbs-config.json"

  @spec load :: Data.t()
  def load do
    @config_file
    |> File.read()
    |> case do
      {:ok, conf_data} ->
        conf_data

      {:error, reason} ->
        Utils.halt("Cannot read configuration file #{@config_file} (#{reason})")
    end
    |> decode()
    |> add_defaults()
    |> validate()
    |> to_struct()
  end

  defp decode(conf_data) do
    conf_data
    |> Jason.decode()
    |> case do
      {:ok, conf} ->
        conf

      {:error, reason} ->
        Utils.halt("Error parsing configuration file #{@config_file}\n  #{Jason.DecodeError.message(reason)}")
    end
  end

  defp add_defaults(conf) do
    conf = put_in(conf["root_dir"], mbs_root_dir())

    conf =
      if conf["parallelism"] == nil do
        put_in(conf["parallelism"], :erlang.system_info(:logical_processors))
      else
        conf
      end

    conf =
      if conf["timeout"] == nil do
        put_in(conf["timeout"], :infinity)
      else
        conf
      end

    conf
  end

  defp mbs_root_dir do
    case System.get_env("MBS_ROOT") do
      nil ->
        Utils.halt("Missing MBS_ROOT environment variable")

      root_dir ->
        root_dir
    end
  end

  defp validate(conf) do
    validate_root_dir(conf["root_dir"])
    validate_parallelism(conf["parallelism"])
    validate_cache(conf["cache"])
    validate_timeout(conf["timeout"])
    conf
  end

  def validate_root_dir(root_dir) do
    unless is_binary(root_dir) and File.exists?(root_dir) do
      Utils.halt("Bad root_dir in #{@config_file}")
    end
  end

  def validate_parallelism(parallelism) do
    unless is_integer(parallelism) and parallelism > 0 do
      Utils.halt("Bad parallelism in #{@config_file}")
    end
  end

  def validate_cache(cache) do
    unless is_binary(cache["dir"]) and Path.type(cache["dir"]) == :relative do
      Utils.halt("Bad cache dir in #{@config_file}. Should be a relative path (in the repo root)")
    end
  end

  def validate_timeout(timeout) do
    unless timeout == :infinity or (is_integer(timeout) and timeout > 0) do
      Utils.halt("Bad timeout in #{@config_file}")
    end
  end

  defp to_struct(conf) do
    %Data{
      root_dir: conf["root_dir"],
      parallelism: conf["parallelism"],
      cache: %Data.Cache{
        dir: conf["cache"]["dir"] |> Path.expand()
      },
      timeout: conf["timeout"]
    }
  end
end
