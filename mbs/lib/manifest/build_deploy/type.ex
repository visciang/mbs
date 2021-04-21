defmodule MBS.Manifest.BuildDeploy.Type do
  @moduledoc false

  @type type :: :build | :deploy
  @type t :: MBS.Manifest.BuildDeploy.Component.t() | MBS.Manifest.BuildDeploy.Toolchain.t()
end

defmodule MBS.Manifest.BuildDeploy.Component do
  @moduledoc false

  defstruct [
    :type,
    :id,
    :dir,
    :timeout,
    :toolchain,
    :toolchain_opts,
    :files,
    :targets,
    :dependencies,
    :services,
    :docker_opts
  ]

  @type t :: %__MODULE__{
          type: MBS.Manifest.BuildDeploy.Type.type(),
          id: String.t(),
          dir: Path.t(),
          timeout: timeout(),
          toolchain: MBS.Manifest.BuildDeploy.Toolchain.t(),
          toolchain_opts: [String.t()],
          files: nonempty_list(String.t()) | nonempty_list(MBS.Manifest.BuildDeploy.Target.t()),
          targets: nonempty_list(MBS.Manifest.BuildDeploy.Target.t()),
          dependencies: [String.t()],
          services: nil | Path.t(),
          docker_opts: [String.t()]
        }
end

defmodule MBS.Manifest.BuildDeploy.Toolchain do
  @moduledoc false

  defstruct [
    :type,
    :id,
    :dir,
    :timeout,
    :checksum,
    :dockerfile,
    :files,
    :deps_change_step,
    :steps,
    :destroy_steps,
    :docker_opts
  ]

  @type t :: %__MODULE__{
          type: MBS.Manifest.BuildDeploy.Type.type(),
          id: String.t(),
          dir: Path.t(),
          timeout: timeout(),
          checksum: String.t(),
          dockerfile: String.t(),
          files: nonempty_list(String.t()),
          deps_change_step: nil | String.t(),
          steps: nonempty_list(String.t()),
          destroy_steps: [String.t()],
          docker_opts: [String.t()]
        }
end

defmodule MBS.Manifest.BuildDeploy.Target do
  @moduledoc false

  defstruct [:type, :target]

  @type type :: :docker | :file

  @type t :: %__MODULE__{
          type: type(),
          target: String.t()
        }
end
