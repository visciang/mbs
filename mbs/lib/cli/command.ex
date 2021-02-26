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
      |> Map.new(&{&1.name, &1})

    print_tree(Map.keys(manifests_map), manifests_map, "")

    :ok
  end

  def cmd(%Args.Ls{verbose: verbose}, %MBS.Config.Data{}, _reporter) do
    print_fun =
      if verbose do
        fn %Manifest.Data{} = manifest ->
          IO.puts(IO.ANSI.format([:bright, "\n- #{manifest.name}"], true))
          IO.puts("  directory: #{manifest.dir}")
          IO.puts("  job.command: #{inspect(manifest.job.command)}")
          IO.puts("  job.dependencies: #{inspect(manifest.job.dependencies)}")
          IO.puts("  job.targets: #{inspect(manifest.job.targets)}")
          IO.puts("  job.files:")
          Enum.each(manifest.job.files, & IO.puts("    #{&1}"))
        end
      else
        &IO.puts(IO.ANSI.format([:bright, &1.name], true))
      end

    Manifest.find_all()
    |> Enum.sort_by(& &1.name)
    |> Enum.each(print_fun)

    :ok
  end

  def cmd(%Args.Graph{png_file: png_file}, %MBS.Config.Data{} = config, reporter) do
    Manifest.find_all()
    |> MBS.Workflow.workflow(config, reporter, fn _, _, _ -> :ok end)
    |> Workflow.Dot.export()
    |> Workflow.Utils.dot_to_png(png_file)

    :ok
  end

  def cmd(%Args.Run{}, %MBS.Config.Data{} = config, reporter) do
    workflow =
      Manifest.find_all()
      |> MBS.Workflow.workflow(config, reporter, &Job.job_fun/3)

    workflow =
      try do
        Workflow.async(workflow, config.parallelism)
      rescue
        error in [Workflow.Error] ->
          Utils.halt(error.message)
      end

    Workflow.await(workflow)
  end

  def cmd(%Args.Outdated{}, %MBS.Config.Data{} = config, reporter) do
    workflow =
      Manifest.find_all()
      |> MBS.Workflow.workflow(config, reporter, &Job.outdated_fun/3)

    workflow =
      try do
        Workflow.async(workflow, config.parallelism)
      rescue
        error in [Workflow.Error] ->
          Utils.halt(error.message)
      end

    Workflow.await(workflow)
  end

  defp print_tree(names, manifests_map, indent) do
    names
    |> Enum.sort()
    |> Enum.each(fn name ->
      IO.puts(IO.ANSI.format([indent, :bright, name], true))
      print_tree(manifests_map[name].job.dependencies, manifests_map, ["  " | indent])
    end)
  end
end
