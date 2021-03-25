defmodule MBS.Manifest.Type do
  @moduledoc false

  @type type :: :build | :deploy
  @type t :: MBS.Manifest.Component.t() | MBS.Manifest.Toolchain.t()
end

defmodule MBS.Manifest.Component do
  @moduledoc false

  defstruct [:type, :id, :dir, :timeout, :toolchain, :toolchain_opts, :files, :targets, :dependencies]

  @type t :: %__MODULE__{
          type: MBS.Manifest.Type.type(),
          id: String.t(),
          dir: Path.t(),
          timeout: timeout(),
          toolchain: MBS.Manifest.Toolchain.t(),
          toolchain_opts: [String.t()],
          files: nonempty_list(String.t()) | nonempty_list(MBS.Manifest.Target.t()),
          targets: nonempty_list(String.t()),
          dependencies: [String.t()]
        }
end

defmodule MBS.Manifest.Toolchain do
  @moduledoc false

  defstruct [:type, :id, :dir, :timeout, :checksum, :dockerfile, :files, :steps]

  @type t :: %__MODULE__{
          type: MBS.Manifest.Type.type(),
          id: String.t(),
          dir: Path.t(),
          timeout: timeout(),
          checksum: String.t(),
          dockerfile: String.t(),
          files: nonempty_list(String.t()),
          steps: nonempty_list(String.t())
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

defmodule MBS.Manifest.Release do
  @moduledoc false

  defstruct [:id, :checksum, :metadata]

  @type t :: %__MODULE__{
          id: String.t(),
          checksum: String.t(),
          metadata: nil | String.t()
        }
end
