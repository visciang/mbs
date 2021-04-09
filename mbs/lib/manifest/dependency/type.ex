defmodule MBS.Manifest.Dependency.Type do
  @moduledoc false

  defstruct [:id, :checksum]

  @type t :: %__MODULE__{
          id: String.t(),
          checksum: String.t()
        }
end