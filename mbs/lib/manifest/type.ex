defmodule MBS.Manifest.Type do
  @moduledoc false

  @type type :: :build | :deploy
  @type t :: MBS.Manifest.Component.t() | MBS.Manifest.Toolchain.t()
end

defmodule MBS.Manifest.Component do
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
          type: MBS.Manifest.Type.type(),
          id: String.t(),
          dir: Path.t(),
          timeout: timeout(),
          toolchain: MBS.Manifest.Toolchain.t(),
          toolchain_opts: [String.t()],
          files: nonempty_list(String.t()) | nonempty_list(MBS.Manifest.Target.t()),
          targets: nonempty_list(MBS.Manifest.Target.t()),
          dependencies: [String.t()],
          services: nil | Path.t(),
          docker_opts: [String.t()]
        }
end

defmodule MBS.Manifest.Toolchain do
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
          type: MBS.Manifest.Type.type(),
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

defmodule MBS.Manifest.Target do
  @moduledoc false

  defstruct [:type, :target]

  @type t :: %__MODULE__{
          type: :docker | :file,
          target: String.t()
        }
end
