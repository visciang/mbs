defmodule MBS.CLI.Command.CachePrune do
  @moduledoc false

  defstruct []

  @type t :: %__MODULE__{}
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.CachePrune do
  alias MBS.CLI.Command
  alias MBS.{Config, Const, Docker}

  @spec run(Command.CachePrune.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.CachePrune{}, %Config.Data{} = _config, _cwd) do
    with :ok <- run_local_cache(),
         :ok <- run_docker_registry() do
      :ok
    else
      _ ->
        :error
    end
  end

  @spec run_local_cache :: :ok
  defp run_local_cache do
    Const.local_cache_dir()
    |> File.ls!()
    |> Enum.map(&Path.join(Const.local_cache_dir(), &1))
    |> Enum.each(&File.rm_rf!/1)

    [:bright, :green, "\nPruned local cache :  ", :normal, Const.local_cache_dir(), "\n"]
    |> IO.ANSI.format()
    |> IO.puts()
  end

  @spec run_docker_registry :: :ok
  defp run_docker_registry do
    case Docker.system_prune() do
      :ok ->
        [:bright, :green, "\nPruned local cache :  ", :normal, Const.local_cache_dir(), "\n"]
        |> IO.ANSI.format()
        |> IO.puts()

      {:error, reason} ->
        [:bright, :red, "Docker system prune error:\n#{inspect(reason)}\n"]
        |> IO.ANSI.format()
        |> IO.puts()

        :error
    end
  end
end
