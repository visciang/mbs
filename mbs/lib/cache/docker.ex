defmodule MBS.Cache.Docker do
  @moduledoc """
  Artifact Cache for docker
  """

  alias MBS.CLI.Reporter
  alias MBS.{Const, Docker}

  require MBS.CLI.Reporter.Status

  @spec put(String.t(), String.t()) :: :ok
  def put(checksum, name) do
    if Const.push() do
      Reporter.job_report(
        name,
        Reporter.Status.log(),
        "CACHE: PUSH docker image #{repository(name)}:#{checksum}",
        nil
      )

      :ok = Docker.image_tag(name, checksum, repository(name), checksum)
      :ok = Docker.image_push(repository(name), checksum)
    end

    :ok
  end

  @spec get(String.t(), String.t()) :: :ok | :error
  def get(checksum, name) do
    with {:local_cache, false} <- {:local_cache, Docker.image_exists(name, checksum)},
         {:cache, false} <- {:cache, Docker.image_exists(repository(name), checksum)} do
      :error
    else
      {:local_cache, true} ->
        :ok

      {:cache, true} ->
        Reporter.job_report(
          name,
          Reporter.Status.log(),
          "CACHE: PULL docker image #{repository(name)}:#{checksum}",
          nil
        )

        :ok = Docker.image_pull(repository(name), checksum)
        :ok = Docker.image_tag(repository(name), checksum, name, checksum)

        :ok
    end
  end

  @spec hit(String.t(), String.t()) :: boolean()
  def hit(checksum, name) do
    Docker.image_exists(name, checksum) or Docker.image_exists(repository(name), checksum)
  end

  @spec path_local(String.t(), String.t()) :: String.t()
  def path_local(checksum, name) do
    "#{name}:#{checksum}"
  end

  defp repository(name) do
    authority = URI.parse(Const.docker_registry()).authority
    "#{authority}/#{name}"
  end
end
