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
    run_local_cache()
    run_docker_registry()

    :ok
  end

  @spec run_local_cache :: :ok
  defp run_local_cache do
    Const.local_cache_dir()
    |> File.ls!()
    |> Enum.each(&File.rm_rf!(Path.join(Const.local_cache_dir(), &1)))

    IO.puts(
      IO.ANSI.format([:bright, :green, "\nPruned local cache volume:  ", :normal, Const.local_cache_volume(), "\n"])
    )
  end

  @spec run_docker_registry :: :ok
  defp run_docker_registry do
    Docker.image_rm_project()

    IO.puts(IO.ANSI.format([:bright, :green, "\nPruned local docker registry\n\n"]))

    IO.puts("""
    NOTE:
      removed all docker image labeled with MBS_PROJECT_ID=#{Const.project_id()}

      Please consider to label all your project docker image with this label if you want them
      to be part of the prune action.
      For example in you docker toolchain use:
        docker image build --label MBS_PROJECT_ID=${MBS_PROJECT_ID} ...)

      Dangling docker images are not removed, run "docker image prune" to remove them
    """)
  end
end
