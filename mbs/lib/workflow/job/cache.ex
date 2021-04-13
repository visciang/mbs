defmodule MBS.Workflow.Job.Cache do
  @moduledoc """
  Workflow job cache utils
  """

  alias MBS.CLI.Reporter
  alias MBS.{Cache, Const, Docker}
  alias MBS.Manifest.BuildDeploy.Target

  require MBS.CLI.Reporter.Status

  @type cache_result :: :cache_miss | :cached

  @spec hit_toolchain(String.t(), String.t()) :: boolean()
  def hit_toolchain(id, checksum) do
    Docker.image_exists(id, checksum)
  end

  @spec hit_targets(String.t(), String.t(), [String.t()]) :: boolean
  def hit_targets(id, checksum, targets) do
    Enum.all?(targets, fn
      %Target{type: :file, target: target} ->
        Cache.hit(Const.cache_dir(), id, checksum, target)

      %Target{type: :docker, target: target} ->
        Docker.image_exists(target, checksum)
    end)
  end

  @spec get_toolchain(String.t(), String.t()) :: cache_result()
  def get_toolchain(id, checksum) do
    if hit_toolchain(id, checksum) do
      :cached
    else
      :cache_miss
    end
  end

  @spec get_targets(String.t(), String.t(), [String.t()]) :: cache_result()
  def get_targets(id, checksum, targets) do
    found_all_targets =
      Enum.all?(targets, fn
        %Target{type: :file, target: target} ->
          match?({:ok, _}, Cache.get(Const.cache_dir(), id, checksum, target))

        %Target{type: :docker, target: target} ->
          Docker.image_exists(target, checksum)
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
        target_cache_path = Cache.path(Const.cache_dir(), id, checksum, target)
        put_in(t.target, target_cache_path)

      %Target{type: :docker, target: target} = t ->
        put_in(t.target, "#{target}:#{checksum}")
    end)
  end

  @spec put_targets(String.t(), String.t(), [String.t()]) :: :ok
  def put_targets(id, checksum, targets) do
    Enum.each(targets, fn
      %Target{type: :file, target: target} ->
        Cache.put(Const.cache_dir(), id, checksum, target)

      %Target{type: :docker, target: _target} ->
        :ok
    end)

    :ok
  end

  @spec put_toolchain(String.t(), String.t()) :: :ok
  def put_toolchain(_id, _checksum), do: :ok

  @spec copy_targets(String.t(), String.t(), [Target.t()], Path.t()) :: :ok | {:error, term()}
  def copy_targets(id, checksum, targets, output_dir) do
    File.mkdir_p!(output_dir)

    Enum.reduce_while(targets, :ok, fn
      %Target{type: :file, target: target}, _ ->
        if Cache.hit(Const.cache_dir(), id, checksum, target) do
          cache_target_path = Cache.path(Const.cache_dir(), id, checksum, target)
          release_target_path = Path.join(output_dir, Path.basename(target))

          report_msg = "cp #{cache_target_path} #{release_target_path}"
          Reporter.job_report(id, Reporter.Status.log(), report_msg, nil)

          File.cp!(cache_target_path, release_target_path)

          {:cont, :ok}
        else
          {:halt, {:error, "Missing target #{target}. Have you run a build?"}}
        end

      %Target{type: :docker, target: target}, _ ->
        with true <- Docker.image_exists(target, checksum),
             :ok <- Docker.image_save(target, checksum, output_dir, id) do
          {:cont, :ok}
        else
          false ->
            {:halt, {:error, "Missing target docker image #{target}:#{checksum}. Have you run a build?"}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end
end
