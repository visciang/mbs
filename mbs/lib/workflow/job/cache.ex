defmodule MBS.Workflow.Job.Cache do
  @moduledoc """
  Workflow job cache utils
  """

  alias MBS.{Cache, Docker}

  def hit_toolchain(id, checksum) do
    Docker.image_exists(id, checksum)
  end

  def hit_targets(cache_directory, id, checksum, job_targets) do
    Enum.all?(job_targets, &Cache.hit(cache_directory, id, checksum, Path.basename(&1)))
  end

  def get_toolchain(id, checksum) do
    if hit_toolchain(id, checksum) do
      :cached
    else
      if Docker.image_pull(id, checksum) == :ok do
        :cached
      else
        :cache_miss
      end
    end
  end

  def get_targets(cache_directory, id, checksum, job_targets) do
    found_all_targets = Enum.all?(job_targets, &(Cache.get(cache_directory, id, checksum, Path.basename(&1)) == :ok))

    if found_all_targets do
      :cached
    else
      :cache_miss
    end
  end

  def put_targets(cache_directory, id, checksum, job_targets) do
    Enum.each(job_targets, &Cache.put(cache_directory, id, checksum, &1))

    :ok
  end

  def put_toolchain(_id, _checksum) do
    :ok
  end
end
