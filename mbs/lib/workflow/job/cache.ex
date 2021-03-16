defmodule MBS.Workflow.Job.Cache do
  @moduledoc """
  Workflow job cache utils
  """

  alias MBS.CLI.Reporter
  alias MBS.{Cache, Docker}
  alias MBS.Manifest.Target

  require MBS.CLI.Reporter.Status

  @spec hit_toolchain(String.t(), String.t()) :: boolean()
  def hit_toolchain(id, checksum) do
    Docker.image_exists(id, checksum)
  end

  @spec hit_targets(Path.t(), String.t(), String.t(), [String.t()]) :: boolean
  def hit_targets(cache_dir, id, checksum, targets) do
    Enum.all?(targets, fn
      %Target{type: :file, target: target} ->
        Cache.hit(cache_dir, id, checksum, target)

      %Target{type: :docker, target: target} ->
        Docker.image_exists(target, checksum)
    end)
  end

  @spec get_toolchain(String.t(), String.t()) :: :cache_miss | :cached
  def get_toolchain(id, checksum) do
    if hit_toolchain(id, checksum) do
      :cached
    else
      :cache_miss
    end
  end

  @spec get_targets(Path.t(), String.t(), String.t(), [String.t()]) :: :cache_miss | :cached
  def get_targets(cache_dir, id, checksum, targets) do
    found_all_targets =
      Enum.all?(targets, fn
        %Target{type: :file, target: target} ->
          Cache.get(cache_dir, id, checksum, target) == :ok

        %Target{type: :docker, target: target} ->
          Docker.image_exists(target, checksum)
      end)

    if found_all_targets do
      :cached
    else
      :cache_miss
    end
  end

  @spec put_targets(Path.t(), String.t(), String.t(), [String.t()]) :: :ok
  def put_targets(cache_dir, id, checksum, targets) do
    Enum.each(targets, fn
      %Target{type: :file, target: target} ->
        Cache.put(cache_dir, id, checksum, target)

      %Target{type: :docker, target: _target} ->
        :ok
    end)

    :ok
  end

  @spec put_toolchain(String.t(), String.t()) :: :ok
  def put_toolchain(_id, _checksum) do
    :ok
  end

  @spec copy_targets(Path.t(), String.t(), String.t(), [Target.t()], Path.t(), Reporter.t()) :: :ok | {:error, term()}
  def copy_targets(cache_dir, id, checksum, targets, output_dir, reporter) do
    File.mkdir_p!(output_dir)

    Enum.reduce_while(targets, :ok, fn
      %Target{type: :file, target: target}, _ ->
        if Cache.hit(cache_dir, id, checksum, target) do
          cache_target_path = Cache.path(cache_dir, id, checksum, target)
          release_target_path = Path.join(output_dir, Path.basename(target))

          Reporter.job_report(
            reporter,
            id,
            Reporter.Status.log(),
            "cp #{cache_target_path} #{release_target_path}",
            nil
          )

          File.cp!(cache_target_path, release_target_path)

          {:cont, :ok}
        else
          {:halt, {:error, "Missing target #{target}. Have you run a build?"}}
        end

      %Target{type: :docker, target: target}, _ ->
        with {:ok, image_id} when is_binary(image_id) <- Docker.image_id(target, checksum),
             :ok <- Docker.image_save(target, checksum, output_dir, reporter, id) do
          {:cont, :ok}
        else
          {:ok, nil} ->
            {:halt, {:error, "Missing target docker image #{target}:#{checksum}. Have you run a build?"}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end
end
