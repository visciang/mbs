defmodule MBS.Workflow.Job.RunBuild do
  @moduledoc """
  Workflow job logic for "build run" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Docker, Utils}
  alias MBS.Manifest.{BuildDeploy, Dependency}
  alias MBS.Toolchain
  alias MBS.Workflow.Job
  alias MBS.Workflow.Job.RunBuild.Sandbox

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), boolean(), boolean(), boolean()) :: Job.fun()
  def fun(
        %Config.Data{},
        %BuildDeploy.Toolchain{id: id, checksum: checksum} = toolchain,
        force,
        _force_get_deps,
        _sandboxed
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {cached, report_status, report_desc} =
        with :cache_miss <- cache_get_toolchain(id, checksum, force),
             :ok <- Toolchain.build(toolchain),
             :ok <- Job.Cache.put_toolchain(id, checksum) do
          {false, Reporter.Status.ok(), checksum}
        else
          :cached ->
            {true, Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {false, Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{cached: cached, checksum: checksum, targets: MapSet.new()}
    end
  end

  def fun(%Config.Data{}, %BuildDeploy.Component{id: id} = component, force, get_deps_only, sandboxed) do
    fn _job_id, upstream_results ->
      start_time = Reporter.time()

      checksum = Job.Utils.build_checksum(component, upstream_results)
      sandboxed_component = Sandbox.up(sandboxed, component)

      {cached, report_status, report_desc} =
        if get_deps_only do
          run_get_only_deps(component, sandboxed_component, upstream_results, sandboxed)

          {true, Reporter.Status.uptodate(), checksum}
        else
          run(component, sandboxed_component, checksum, upstream_results, sandboxed, force)
        end

      end_time = Reporter.time()

      Reporter.job_report(id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{
        cached: cached,
        checksum: checksum,
        targets: transitive_targets(id, checksum, sandboxed_component.targets, upstream_results)
      }
    end
  end

  @spec fun_on_exit(Config.Data.t(), BuildDeploy.Type.t(), boolean()) :: Dask.Job.on_exit()
  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Toolchain{} = toolchain, _sandbox) do
    Job.OnExit.fun(config, toolchain)
  end

  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Component{id: id} = component, sandbox) do
    job_on_exit = Job.OnExit.fun(config, component)

    fn _job_id, upstream_results, job_exec_result, elapsed_time_ms ->
      job_started? =
        case job_exec_result do
          {:job_ok, %Job.FunResult{cached: false}} -> true
          :job_timeout -> true
          _ -> false
        end

      if job_started? do
        Toolchain.exec_services(:down, component, [])
        Sandbox.down(sandbox, component)

        job_on_exit.(id, upstream_results, job_exec_result, elapsed_time_ms)
      end
    end
  end

  @spec run_get_only_deps(BuildDeploy.Component.t(), BuildDeploy.Component.t(), Job.upstream_results(), boolean()) ::
          :ok
  defp run_get_only_deps(
         %BuildDeploy.Component{} = component,
         %BuildDeploy.Component{} = sandboxed_component,
         upstream_results,
         sandboxed
       ) do
    get_dependencies(sandboxed_component, upstream_results, true)
    put_files(sandboxed, component, sandboxed_component)
  end

  @spec run(
          BuildDeploy.Component.t(),
          BuildDeploy.Component.t(),
          String.t(),
          Job.upstream_results(),
          boolean(),
          boolean()
        ) :: {false, :ok | {:error, binary}, nil | binary}
  defp run(
         %BuildDeploy.Component{} = component,
         %BuildDeploy.Component{id: id, targets: targets} = sandboxed_component,
         checksum,
         upstream_results,
         sandboxed,
         force
       ) do
    cache_result =
      if force do
        :cache_miss
      else
        Job.Cache.get_targets(id, checksum, targets)
      end

    with :cache_miss <- cache_result,
         changed_deps = get_dependencies(sandboxed_component, upstream_results, force),
         :ok <- put_files(sandboxed, component, sandboxed_component),
         :ok <- Toolchain.exec_build(sandboxed_component, checksum, upstream_results, changed_deps, sandboxed),
         :ok <- assert_targets(targets, checksum),
         :ok <- Job.Cache.put_targets(id, checksum, sandboxed_component.targets) do
      {false, Reporter.Status.ok(), checksum}
    else
      :cached ->
        {true, Reporter.Status.uptodate(), checksum}

      {:error, reason} ->
        {false, Reporter.Status.error(reason), nil}
    end
  end

  @spec get_dependencies(BuildDeploy.Component.t(), Job.upstream_results(), boolean()) ::
          [{Path.t(), Dependency.Type.t()}]
  defp get_dependencies(%BuildDeploy.Component{} = component, upstream_results, force) do
    changed_deps = get_changed_dependencies_targets(component, upstream_results, force)
    put_dependencies(component, changed_deps)

    changed_deps
  end

  @spec transitive_targets(String.t(), String.t(), [BuildDeploy.Target.t()], Job.upstream_results()) ::
          MapSet.t(BuildDeploy.Target.t())
  defp transitive_targets(id, checksum, targets, upstream_results) do
    expanded_targets = Job.Cache.expand_targets_path(id, checksum, targets)

    expanded_targets_set =
      expanded_targets
      |> Enum.map(&{id, &1})
      |> MapSet.new()

    expanded_upstream_targets_set =
      upstream_results
      |> Map.values()
      |> Enum.map(& &1.targets)
      |> Utils.union_mapsets()

    MapSet.union(expanded_targets_set, expanded_upstream_targets_set)
  end

  @spec cache_get_toolchain(String.t(), String.t(), boolean()) :: Job.Cache.cache_result()
  defp cache_get_toolchain(id, checksum, force) do
    if force do
      :cache_miss
    else
      Job.Cache.get_toolchain(id, checksum)
    end
  end

  @spec get_changed_dependencies_targets(BuildDeploy.Component.t(), Job.upstream_results(), boolean()) ::
          [{Path.t(), Dependency.Type.t()}]
  defp get_changed_dependencies_targets(
         %BuildDeploy.Component{dir: component_dir, toolchain: toolchain},
         upstream_results,
         force
       ) do
    local_deps_dir = Path.join(component_dir, Const.local_dependencies_targets_dir())

    upstream_targets_set =
      upstream_results
      |> Map.values()
      |> Enum.map(& &1.targets)
      |> Utils.union_mapsets()

    res_deps_changed =
      Enum.reduce(upstream_targets_set, [], fn
        {dep_id, %BuildDeploy.Target{type: :file, target: target_cache_path}}, acc ->
          target_checksum = target_cache_path |> Path.dirname() |> Path.basename()
          dependency_manifest_path = Path.join([local_deps_dir, dep_id, Const.manifest_dependency_filename()])

          if force or dependency_changed?(dependency_manifest_path, target_checksum) do
            dependency = %Dependency.Type{id: dep_id, checksum: target_checksum, cache_path: target_cache_path}
            [{dependency_manifest_path, dependency} | acc]
          else
            acc
          end

        {_dep_id, %BuildDeploy.Target{type: :docker}}, acc ->
          acc
      end)

    toolchain_manifest_path = Path.join(local_deps_dir, Const.manifest_dependency_filename())

    res_toolchain_changed =
      if dependency_changed?(toolchain_manifest_path, toolchain.checksum) do
        [{toolchain_manifest_path, %Dependency.Type{id: toolchain.id, checksum: toolchain.checksum}}]
      else
        []
      end

    res_toolchain_changed ++ res_deps_changed
  end

  @spec dependency_changed?(Path.t(), String.t()) :: boolean()
  defp dependency_changed?(path, checksum) do
    if File.exists?(path) do
      dependency_manifest = Dependency.load(path)
      dependency_manifest.checksum != checksum
    else
      true
    end
  end

  @spec put_files(boolean(), BuildDeploy.Component.t(), BuildDeploy.Component.t()) :: :ok
  def put_files(false, _component, _sandboxed_component), do: :ok

  def put_files(true, %BuildDeploy.Component{files: files}, %BuildDeploy.Component{files: sandbox_files}) do
    sandbox_files
    |> paths_dirname()
    |> Enum.each(&File.mkdir_p!/1)

    Enum.zip(files, sandbox_files)
    |> Enum.each(fn {file, sandbox_file} -> File.cp!(file, sandbox_file) end)
  end

  @spec put_dependencies(BuildDeploy.Component.t(), [{Path.t(), Dependency.Type.t()}]) :: :ok
  defp put_dependencies(%BuildDeploy.Component{dir: component_dir}, deps) do
    local_deps_dir = Path.join(component_dir, Const.local_dependencies_targets_dir())
    File.mkdir_p!(local_deps_dir)

    deps
    |> Enum.reject(&match?({_, %Dependency.Type{cache_path: nil}}, &1))
    |> Enum.each(fn {_, %Dependency.Type{id: dep_id, cache_path: target_cache_path}} ->
      dest_dir = Path.join(local_deps_dir, dep_id)
      File.mkdir_p!(Path.join(local_deps_dir, dep_id))
      File.cp!(target_cache_path, Path.join(dest_dir, Path.basename(target_cache_path)))
    end)
  end

  @spec assert_targets([BuildDeploy.Target.t()], String.t()) :: :ok | {:error, String.t()}
  defp assert_targets(targets, checksum) do
    missing_docker_targets =
      targets
      |> filter_targets(:docker)
      |> Enum.filter(&(not Docker.image_exists(&1, checksum)))

    missing_file_targets =
      targets
      |> filter_targets(:file)
      |> Enum.filter(&(not File.exists?(&1)))

    missing_targets = missing_docker_targets ++ missing_file_targets

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      :ok
    end
  end

  @spec paths_dirname([Path.t()]) :: MapSet.t(Path.t())
  defp paths_dirname(paths), do: MapSet.new(paths, &Path.dirname(&1))

  @spec filter_targets([BuildDeploy.Target.t()], BuildDeploy.Target.type()) :: [Path.t()]
  defp filter_targets(targets, type) do
    targets
    |> Enum.filter(&match?(%BuildDeploy.Target{type: ^type}, &1))
    |> Enum.map(& &1.target)
  end
end
