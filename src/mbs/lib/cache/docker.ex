defmodule MBS.Cache.Docker do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Docker}

  require MBS.CLI.Reporter.Status

  @spec put(Config.Data.t(), String.t(), String.t()) :: :ok
  def put(%Config.Data{cache: %Config.Data.Cache{push: push}} = config, checksum, name) do
    if push do
      repository_ = repository(config, name)

      Reporter.job_report(
        name,
        Reporter.Status.log(),
        "CACHE: PUSH docker image #{repository_}:#{checksum}",
        nil
      )

      :ok = Docker.image_tag(name, checksum, repository_, checksum)
      :ok = Docker.image_push(repository_, checksum)
    end

    :ok
  end

  @spec get(Config.Data.t(), String.t(), String.t()) :: :ok | :error
  def get(%Config.Data{} = config, checksum, name) do
    with {:local_cache, false} <- {:local_cache, Docker.image_exists(name, checksum)},
         repository_ = repository(config, name),
         {:cache, false} <- {:cache, Docker.image_exists(repository_, checksum)} do
      :error
    else
      {:local_cache, true} ->
        :ok

      {:cache, true} ->
        repository_ = repository(config, name)

        Reporter.job_report(
          name,
          Reporter.Status.log(),
          "CACHE: PULL docker image #{repository_}:#{checksum}",
          nil
        )

        :ok = Docker.image_pull(repository_, checksum)
        :ok = Docker.image_tag(repository_, checksum, name, checksum)

        :ok
    end
  end

  @spec hit(Config.Data.t(), String.t(), String.t()) :: boolean()
  def hit(%Config.Data{} = config, checksum, name) do
    Docker.image_exists(name, checksum) or Docker.image_exists(repository(config, name), checksum)
  end

  @spec path_local(String.t(), String.t()) :: String.t()
  def path_local(checksum, name) do
    "#{name}:#{checksum}"
  end

  @spec repository(Config.Data.t(), String.t()) :: String.t()
  defp repository(%Config.Data{cache: %Config.Data.Cache{docker_registry: docker_registry}}, name) do
    if docker_registry != nil do
      authority = URI.parse(docker_registry).authority
      "#{authority}/#{name}"
    else
      name
    end
  end
end
