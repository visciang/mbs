defmodule MBS.ReleaseManifest.Release do
  @moduledoc false

  defstruct [:id, :checksum, :metadata]

  @type t :: %__MODULE__{
          id: String.t(),
          checksum: String.t(),
          metadata: nil | String.t()
        }
end
