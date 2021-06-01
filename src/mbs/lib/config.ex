defmodule MBS.Config.Data do
  @moduledoc false

  defmodule Cache do
    @moduledoc false
    defstruct [:push, :volume, :docker_registry]

    @type t :: %__MODULE__{
            push: boolean(),
            volume: nil | String.t(),
            docker_registry: nil | String.t()
          }
  end

  defmodule Log do
    @moduledoc false
    defstruct [:level, :color]

    @type t :: %__MODULE__{
            level: Logger.level(),
            color: boolean()
          }
  end

  defstruct [:project, :log, :cache, :parallelism, :timeout, :files_profile]

  @type files_profiles :: %{String.t() => [String.t()]}

  @type t :: %__MODULE__{
          project: String.t(),
          log: __MODULE__.Log.t(),
          cache: __MODULE__.Cache.t(),
          parallelism: non_neg_integer(),
          timeout: timeout(),
          files_profile: files_profiles()
        }
end

defmodule MBS.Config do
  @moduledoc false

  alias MBS.Config.Data
  alias MBS.{Const, Utils}

  @spec logger(Data.t()) :: :ok
  def logger(%Data{log: %Data.Log{level: level, color: color}}) do
    Logger.configure(level: level)
    Application.put_env(:elixir, :ansi_enabled, color)
  end

  @spec load(Path.t()) :: Data.t()
  def load(cwd) do
    config_file = Path.join(cwd, Const.config_file())

    config_file
    |> File.read()
    |> case do
      {:ok, conf_data} ->
        conf_data

      {:error, reason} ->
        Utils.halt("Cannot read configuration file #{config_file} (#{reason})")
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
    conf
    |> update_in(["cache"], &(&1 || %{"push" => false, "volume" => nil, "docker_registry" => nil}))
    |> update_in(["parallelism"], &(&1 || :erlang.system_info(:logical_processors)))
    |> update_in(["timeout"], &(&1 || :infinity))
    |> update_in(["files_profile"], &(&1 || %{}))
  end

  @spec validate(map()) :: map()
  defp validate(conf) do
    validate_project(conf["project"])
    validate_log(conf["log"])
    validate_cache(conf["cache"])
    validate_parallelism(conf["parallelism"])
    validate_timeout(conf["timeout"])
    validate_files_profile(conf["files_profile"])
    conf
  end

  @spec validate_project(String.t()) :: nil
  defp validate_project(project) do
    unless is_binary(project) do
      Utils.halt("Bad project in #{Const.config_file()}")
    end
  end

  @spec validate_log(map()) :: nil
  defp validate_log(log) do
    unless is_map(log) do
      Utils.halt("Bad log in #{Const.config_file()}")
    end

    unless is_binary(log["level"]) do
      Utils.halt("Bad log.color in #{Const.config_file()}")
    end

    unless is_boolean(log["color"]) do
      Utils.halt("Bad log.color in #{Const.config_file()}")
    end
  end

  @spec validate_cache(map()) :: nil
  defp validate_cache(cache) do
    unless is_map(cache) do
      Utils.halt("Bad cache in #{Const.config_file()}")
    end

    unless is_boolean(cache["push"]) do
      Utils.halt("Bad cache.push in #{Const.config_file()}")
    end

    unless is_nil(cache["volume"]) or is_binary(cache["volume"]) do
      Utils.halt("Bad cache.volume in #{Const.config_file()}")
    end

    unless is_nil(cache["docker_registry"]) or is_binary(cache["docker_registry"]) do
      Utils.halt("Bad cache.docker_registry in #{Const.config_file()}")
    end
  end

  @spec validate_parallelism(pos_integer()) :: nil
  defp validate_parallelism(parallelism) do
    unless is_integer(parallelism) and parallelism > 0 do
      Utils.halt("Bad parallelism in #{Const.config_file()}")
    end
  end

  @spec validate_timeout(timeout()) :: nil
  defp validate_timeout(timeout) do
    unless timeout == :infinity or (is_integer(timeout) and timeout > 0) do
      Utils.halt("Bad timeout in #{Const.config_file()}")
    end
  end

  @spec validate_timeout(map()) :: nil
  defp validate_files_profile(files_profile) do
    unless is_map(files_profile) do
      Utils.halt("Bad files_profile in #{Const.config_file()}")
    end

    Enum.each(files_profile, fn {profile_id, files} ->
      unless Enum.all?(files, &is_binary/1) do
        Utils.halt("Bad #{profile_id} files_profile value in #{Const.config_file()}")
      end
    end)

    nil
  end

  @spec to_struct(map()) :: Data.t()
  defp to_struct(conf) do
    %Data{
      project: conf["project"],
      log: %Data.Log{
        level: conf["log"]["level"] |> String.to_atom(),
        color: conf["log"]["color"]
      },
      cache: %Data.Cache{
        push: conf["cache"]["push"],
        volume: conf["cache"]["volume"],
        docker_registry: conf["cache"]["docker_registry"]
      },
      parallelism: conf["parallelism"],
      timeout: conf["timeout"],
      files_profile: conf["files_profile"]
    }
  end
end
