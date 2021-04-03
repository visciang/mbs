defmodule MBS.Config.Data do
  @moduledoc false

  defmodule Cache do
    @moduledoc false
    defstruct [:dir]

    @type t :: %__MODULE__{
            dir: Path.t()
          }
  end

  defstruct [:parallelism, :timeout]

  @type t :: %__MODULE__{
          parallelism: non_neg_integer(),
          timeout: timeout()
        }
end

defmodule MBS.Config do
  @moduledoc """
  Global config
  """

  require Logger

  alias MBS.Config.Data
  alias MBS.{Const, Utils}

  @spec load :: Data.t()
  def load do
    Const.config_file()
    |> File.read()
    |> case do
      {:ok, conf_data} ->
        conf_data

      {:error, reason} ->
        Utils.halt("Cannot read configuration file #{Const.config_file()} (#{reason})")
    end
    |> decode()
    |> add_defaults()
    |> validate()
    |> to_struct()
  end

  @spec decode(String.t()) :: map()
  defp decode(conf_data) do
    conf_data
    |> Jason.decode()
    |> case do
      {:ok, conf} ->
        conf

      {:error, reason} ->
        Utils.halt("Error parsing configuration file #{Const.config_file()}\n  #{Jason.DecodeError.message(reason)}")
    end
  end

  @spec add_defaults(map()) :: map()
  defp add_defaults(conf) do
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

  @spec validate(map()) :: map()
  defp validate(conf) do
    validate_parallelism(conf["parallelism"])
    validate_timeout(conf["timeout"])
    conf
  end

  @spec validate_parallelism(non_neg_integer()) :: :ok
  defp validate_parallelism(parallelism) do
    unless is_integer(parallelism) and parallelism > 0 do
      Utils.halt("Bad parallelism in #{Const.config_file()}")
    end

    :ok
  end

  @spec validate_timeout(timeout()) :: :ok
  defp validate_timeout(timeout) do
    unless timeout == :infinity or (is_integer(timeout) and timeout > 0) do
      Utils.halt("Bad timeout in #{Const.config_file()}")
    end

    :ok
  end

  @spec to_struct(map()) :: Data.t()
  defp to_struct(conf) do
    %Data{
      parallelism: conf["parallelism"],
      timeout: conf["timeout"]
    }
  end
end
