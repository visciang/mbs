defmodule MBS.Manifest.Type do
  @moduledoc false

  @type t :: MBS.Manifest.Component.t() | MBS.Manifest.Toolchain.t()
end

defmodule MBS.Manifest.Component do
  @moduledoc false

  defstruct [:id, :dir, :timeout, :toolchain, :toolchain_opts, :files, :targets, :dependencies]

  @type t :: %__MODULE__{
          id: String.t(),
          dir: Path.t(),
          timeout: timeout(),
          toolchain: MBS.Manifest.Toolchain.t(),
          toolchain_opts: [String.t()],
          files: nonempty_list(String.t()),
          targets: nonempty_list(String.t()),
          dependencies: [String.t()]
        }
end

defmodule MBS.Manifest.Toolchain do
  @moduledoc false

  defstruct [:id, :dir, :timeout, :checksum, :dockerfile, :files, :steps]

  @type t :: %__MODULE__{
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
