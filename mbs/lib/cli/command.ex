defmodule MBS.CLI.Command do
  @moduledoc """
  CLI commands
  """

  alias MBS.{Manifest, Utils}
  alias MBS.CLI.{Args, Reporter}
  alias MBS.Workflow.Job

  require Reporter.Status

  def cmd(%Args.Version{}, %MBS.Config.Data{}, _reporter) do
    {_, vsn} = :application.get_key(:mbs, :vsn)
    IO.puts(vsn)

    :ok
  end

  def cmd(%Args.Tree{}, %MBS.Config.Data{}, _reporter) do
    manifests_map =
      Manifest.find_all()
      |> Map.new(&{&1.id, &1})

    IO.puts("")
    print_tree(Map.keys(manifests_map), manifests_map, "")

    :ok
  end

  def cmd(%Args.Ls{verbose: verbose}, %MBS.Config.Data{}, _reporter) do
    print_fun =
      if verbose do
        fn
          %Manifest.Component{} = component ->
            IO.puts(IO.ANSI.format([:bright, "#{component.id}", :normal, ":"], true))
            IO.puts("  directory:")
            IO.puts("    #{component.dir}")
            IO.puts("  toolchain:")
            IO.puts("    #{component.toolchain.id}")
            IO.puts("  targets:")
            Enum.each(component.targets, &IO.puts("    - #{&1}"))
            IO.puts("  files:")
            Enum.each(component.files, &IO.puts("    - #{&1}"))

            if component.dependencies != [] do
              IO.puts("  dependencies:")
              Enum.each(component.dependencies, &IO.puts("    - #{&1}"))
            end

            IO.puts("")

          %Manifest.Toolchain{} = toolchain ->
            IO.puts(IO.ANSI.format([:bright, "#{toolchain.id}", :normal, ":"], true))
            IO.puts("  directory:")
            IO.puts("    #{toolchain.dir}")
            IO.puts("  dockerfile:")
            IO.puts("    #{toolchain.dockerfile}")
            IO.puts("  steps:")
            Enum.each(toolchain.steps, &IO.puts("    - #{&1}"))
            IO.puts("  files:")
            Enum.each(toolchain.files, &IO.puts("    - #{&1}"))

            IO.puts("")
        end
      else
        &IO.puts(IO.ANSI.format([:bright, &1.id], true))
      end

    IO.puts("")

    Manifest.find_all()
    |> Enum.sort_by(& &1.id)
    |> Enum.each(print_fun)

    :ok
  end

  def cmd(%Args.Graph{png_file: png_file}, %MBS.Config.Data{} = config, reporter) do
    Manifest.find_all()
    |> MBS.Workflow.workflow(config, reporter, fn _, _, _ -> :ok end)
    |> Dask.Dot.export()
    |> Dask.Utils.dot_to_png(png_file)

    :ok
  end

  def cmd(%Args.Run{}, %MBS.Config.Data{} = config, reporter) do
    dask =
      Manifest.find_all()
      |> MBS.Workflow.workflow(config, reporter, &Job.job_fun/3)

    dask =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    Dask.await(dask)
  end

  def cmd(%Args.Outdated{}, %MBS.Config.Data{} = config, reporter) do
    dask =
      Manifest.find_all()
      |> MBS.Workflow.workflow(config, reporter, &Job.outdated_fun/3)

    dask =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    Dask.await(dask)
  end

  defp print_tree(names, manifests_map, indent) do
    names
    |> Enum.sort()
    |> Enum.each(fn id ->
      IO.puts(IO.ANSI.format([indent, :bright, id], true))

      dependencies =
        case manifests_map[id] do
          %Manifest.Component{toolchain: toolchain} ->
            [toolchain.id | manifests_map[id].dependencies]

          %Manifest.Toolchain{} ->
            []
        end

      print_tree(dependencies, manifests_map, ["  " | indent])
    end)
  end
end
