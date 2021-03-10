defmodule MBS.Workflow.Job.Cache do
  @moduledoc """
  Workflow job cache utils
  """

  alias MBS.{Cache, Docker}
  alias MBS.Manifest.Target

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

  @spec copy_targets(Path.t(), String.t(), String.t(), [String.t()], Path.t()) :: :ok | {:error, term()}
  def copy_targets(cache_dir, id, checksum, targets, output_dir) do
    File.mkdir_p!(output_dir)

    Enum.reduce_while(targets, :ok, fn
      %Target{type: :file, target: target}, _ ->
        if Cache.hit(cache_dir, id, checksum, target) do
          cache_target_path = Cache.path(cache_dir, id, checksum, target)
          release_target_path = Path.join(output_dir, Path.basename(target))

          File.cp!(cache_target_path, release_target_path)

          {:cont, :ok}
        else
          {:halt, {:error, "Missing target #{target}. Have you run a build?"}}
        end

      %Target{type: :docker, target: target}, _ ->
        if Docker.image_exists(target, checksum) do
          docker_manifest = %{repository: target, tag: checksum, image_id: Docker.image_id(target, checksum)}
          File.write!(Path.join(output_dir, "#{target}.json"), Jason.encode!(docker_manifest))

          {:cont, :ok}
        else
          {:halt, {:error, "Missing target docker image #{target}:#{checksum}. Have you run a build?"}}
        end
    end)
  end
end
