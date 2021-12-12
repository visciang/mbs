defmodule MBS.Cache.File do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const}

  require MBS.CLI.Reporter.Status

  @spec put(Config.Data.t(), String.t(), String.t(), String.t()) :: :ok
  def put(%Config.Data{remote_cache: %Config.Data.RemoteCache{push: push}}, name, checksum, target) do
    local_cache_dest_target = path_local(name, checksum, target)
    local_cache_dest_dir = Path.dirname(local_cache_dest_target)

    File.mkdir_p!(local_cache_dest_dir)
    File.cp!(target, local_cache_dest_target)

    if push do
      cache_dest_target = path(name, checksum, target)
      cache_dest_dir = Path.dirname(cache_dest_target)

      Reporter.job_report(name, Reporter.Status.log(), "CACHE: PUSH #{cache_dest_target}", nil)

      File.mkdir_p!(cache_dest_dir)
      File.cp!(target, cache_dest_target)
    end
  end

  @spec get(String.t(), String.t(), String.t()) :: {:ok, Path.t()} | :error
  def get(name, checksum, target) do
    local_cache_target_path = path_local(name, checksum, target)
    cache_target_path = path(name, checksum, target)

    with {:local_cache, false} <- {:local_cache, File.exists?(local_cache_target_path)},
         {:cache, false} <- {:cache, File.exists?(cache_target_path)} do
      :error
    else
      {:local_cache, true} ->
        {:ok, local_cache_target_path}

      {:cache, true} ->
        Reporter.job_report(name, Reporter.Status.log(), "CACHE: PULL #{cache_target_path}", nil)

        File.cp!(cache_target_path, local_cache_target_path)
        {:ok, local_cache_target_path}
    end
  end

  @spec hit(String.t(), String.t(), String.t()) :: boolean()
  def hit(name, checksum, target) do
    local_cache_target_path = path_local(name, checksum, target)
    cache_target_path = path(name, checksum, target)

    File.exists?(local_cache_target_path) or File.exists?(cache_target_path)
  end

  @spec path_local(String.t(), String.t(), String.t()) :: Path.t()
  def path_local(name, checksum, target) do
    Path.join([Const.local_cache_dir(), name, checksum, Path.basename(target)])
  end

  @spec path(String.t(), String.t(), String.t()) :: Path.t()
  defp path(name, checksum, target) do
    Path.join([Const.cache_dir(), name, checksum, Path.basename(target)])
  end
end
