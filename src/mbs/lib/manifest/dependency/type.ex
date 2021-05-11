defmodule MBS.Manifest.Dependency.Type do
  @moduledoc false

  defstruct [:id, :checksum, :cache_path]

  @type t :: %__MODULE__{
          id: String.t(),
          checksum: String.t(),
          cache_path: nil | Path.t()
        }
end
