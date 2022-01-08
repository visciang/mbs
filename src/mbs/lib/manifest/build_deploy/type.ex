defmodule MBS.Manifest.BuildDeploy.Type do
  @moduledoc false

  @type type :: :build | :deploy
  @type t :: MBS.Manifest.BuildDeploy.Component.t() | MBS.Manifest.BuildDeploy.Toolchain.t()
end

defmodule MBS.Manifest.BuildDeploy.Component do
  @moduledoc false

  defmodule Target do
    @moduledoc false

    defstruct [:type, :target]

    @type type :: :docker | :file

    @type t :: %__MODULE__{
            type: type(),
            target: String.t()
          }
  end

  defmodule Build do
    @moduledoc false

    defstruct [:files, :targets, :services]

    @type t :: %__MODULE__{
            files: nonempty_list(String.t()),
            targets: nonempty_list(Target.t()),
            services: nil | Path.t()
          }
  end

  defmodule Deploy do
    @moduledoc false

    defstruct [:build_target_dependencies]

    @type t :: %__MODULE__{
            build_target_dependencies: nonempty_list(Target.t())
          }
  end

  defstruct [
    :type,
    :id,
    :dir,
    :project_dir,
    :checksum,
    :toolchain,
    :toolchain_opts,
    :timeout,
    :dependencies,
    :docker_opts
  ]

  @type docker_opts_type :: :run | :shell

  @type t :: %__MODULE__{
          type: Build.t() | Deploy.t(),
          id: String.t(),
          dir: Path.t(),
          project_dir: Path.t(),
          timeout: timeout(),
          checksum: String.t(),
          toolchain: MBS.Manifest.BuildDeploy.Toolchain.t(),
          toolchain_opts: [String.t()],
          dependencies: [t()],
          docker_opts: %{
            docker_opts_type() => [String.t()]
          }
        }

  def dependencies_ids(%__MODULE__{toolchain: toolchain, dependencies: dependencies}) do
    [toolchain.id | Enum.map(dependencies, & &1.id)]
  end
end

defmodule MBS.Manifest.BuildDeploy.Toolchain do
  @moduledoc false

  defstruct [
    :id,
    :dir,
    :project_dir,
    :checksum,
    :files,
    :dockerfile,
    :timeout,
    :steps,
    :destroy_steps,
    :docker_build_opts
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          dir: Path.t(),
          project_dir: Path.t(),
          timeout: timeout(),
          checksum: String.t(),
          dockerfile: String.t(),
          files: nonempty_list(String.t()),
          steps: nonempty_list(String.t()),
          destroy_steps: [String.t()],
          docker_build_opts: [String.t()]
        }
end
