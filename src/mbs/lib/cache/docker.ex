defmodule MBS.Cache.Docker do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Docker}

  require MBS.CLI.Reporter.Status

  @spec put(Config.Data.t(), String.t(), String.t()) :: :ok
  def put(%Config.Data{remote_cache: %Config.Data.RemoteCache{push: push}} = config, checksum, name) do
    if push do
      remote_repository_ = remote_repository(config, name)

      Reporter.job_report(
        name,
        Reporter.Status.log(),
        "CACHE: PUSH docker image #{remote_repository_}:#{checksum}",
        nil
      )

      :ok = Docker.image_tag(name, checksum, remote_repository_, checksum)
      :ok = Docker.image_push(remote_repository_, checksum)
    end

    :ok
  end

  @spec get(Config.Data.t(), String.t(), String.t()) :: :ok | :error
  def get(%Config.Data{} = config, checksum, name) do
    remote_repository_ = remote_repository(config, name)

    with {:local_cache, false} <- {:local_cache, Docker.image_exists(name, checksum)},
         {:remote_cache, {:error, _}} <- {:remote_cache, Docker.image_pull(remote_repository_, checksum)} do
      :error
    else
      {:local_cache, true} ->
        :ok

      {:remote_cache, :ok} ->
        Reporter.job_report(
          name,
          Reporter.Status.log(),
          "CACHE: pulled docker image #{remote_repository_}:#{checksum}",
          nil
        )

        :ok = Docker.image_tag(remote_repository_, checksum, name, checksum)
    end
  end

  @spec hit(Config.Data.t(), String.t(), String.t()) :: boolean()
  def hit(%Config.Data{} = _config, checksum, name) do
    Docker.image_exists(name, checksum)
  end

  @spec path_local(String.t(), String.t()) :: String.t()
  def path_local(checksum, name) do
    "#{name}:#{checksum}"
  end

  @spec remote_repository(Config.Data.t(), String.t()) :: String.t()
  defp remote_repository(%Config.Data{remote_cache: %Config.Data.RemoteCache{docker_registry: docker_registry}}, name) do
    if docker_registry != nil do
      authority = URI.parse(docker_registry).authority
      "#{authority}/#{name}"
    else
      name
    end
  end
end
