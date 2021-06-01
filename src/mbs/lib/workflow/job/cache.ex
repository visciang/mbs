defmodule MBS.Workflow.Job.Cache do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Cache, Config, Docker}
  alias MBS.Manifest.BuildDeploy.Target

  require MBS.CLI.Reporter.Status

  @type cache_result :: :cache_miss | :cached

  @spec hit_toolchain(Config.Data.t(), String.t(), String.t()) :: boolean()
  def hit_toolchain(%Config.Data{} = config, id, checksum) do
    Cache.Docker.hit(config, checksum, id)
  end

  @spec hit_targets(Config.Data.t(), String.t(), String.t(), [Target.t()]) :: boolean
  def hit_targets(%Config.Data{} = config, id, checksum, targets) do
    Enum.all?(targets, fn
      %Target{type: :file, target: target} ->
        Cache.File.hit(id, checksum, target)

      %Target{type: :docker, target: target} ->
        Cache.Docker.hit(config, checksum, target)
    end)
  end

  @spec get_toolchain(Config.Data.t(), String.t(), String.t()) :: cache_result()
  def get_toolchain(%Config.Data{} = config, id, checksum) do
    case Cache.Docker.get(config, checksum, id) do
      :ok -> :cached
      :error -> :cache_miss
    end
  end

  @spec get_targets(Config.Data.t(), String.t(), String.t(), [Target.t()]) :: cache_result()
  def get_targets(%Config.Data{} = config, id, checksum, targets) do
    found_all_targets =
      Enum.all?(targets, fn
        %Target{type: :file, target: target} ->
          match?({:ok, _}, Cache.File.get(id, checksum, target))

        %Target{type: :docker, target: target} ->
          :ok == Cache.Docker.get(config, checksum, target)
      end)

    if found_all_targets do
      :cached
    else
      :cache_miss
    end
  end

  @spec expand_targets_path(String.t(), String.t(), [Target.t()]) :: [Target.t()]
  def expand_targets_path(id, checksum, targets) do
    Enum.map(targets, fn
      %Target{type: :file, target: target} = t ->
        target_cache_path = Cache.File.path_local(id, checksum, target)
        put_in(t.target, target_cache_path)

      %Target{type: :docker, target: target} = t ->
        target_docker = Cache.Docker.path_local(checksum, target)
        put_in(t.target, target_docker)
    end)
  end

  @spec put_targets(Config.Data.t(), String.t(), String.t(), [Target.t()]) :: :ok
  def put_targets(%Config.Data{} = config, id, checksum, targets) do
    Enum.each(targets, fn
      %Target{type: :file, target: target} ->
        Cache.File.put(config, id, checksum, target)

      %Target{type: :docker, target: target} ->
        Cache.Docker.put(config, checksum, target)
    end)
  end

  @spec put_toolchain(Config.Data.t(), String.t(), String.t()) :: :ok
  def put_toolchain(%Config.Data{} = config, id, checksum) do
    Cache.Docker.put(config, checksum, id)
  end

  @spec copy_targets(Config.Data.t(), String.t(), String.t(), [Target.t()], Path.t()) :: :ok | {:error, term()}
  def copy_targets(%Config.Data{} = config, id, checksum, targets, output_dir) do
    File.mkdir_p!(output_dir)

    Enum.reduce_while(targets, :ok, fn
      %Target{type: :file, target: target}, _ ->
        if Cache.File.hit(id, checksum, target) do
          cache_target_path = Cache.File.path_local(id, checksum, target)
          release_target_path = Path.join(output_dir, Path.basename(target))

          report_msg = "cp #{cache_target_path} #{release_target_path}"
          Reporter.job_report(id, Reporter.Status.log(), report_msg, nil)

          File.cp!(cache_target_path, release_target_path)

          {:cont, :ok}
        else
          {:halt, {:error, "Missing target #{target}. Have you run a build?"}}
        end

      %Target{type: :docker, target: target}, _ ->
        with true <- Cache.Docker.hit(config, checksum, target),
             :ok <- Docker.image_save(target, checksum, output_dir, id) do
          {:cont, :ok}
        else
          false ->
            target_docker = Cache.Docker.path_local(checksum, target)
            {:halt, {:error, "Missing target docker image #{target_docker}. Have you run a build?"}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end
end
