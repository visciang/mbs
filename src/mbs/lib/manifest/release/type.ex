defmodule MBS.Manifest.Release.Type do
  @moduledoc false

  alias MBS.Manifest.BuildDeploy

  @enforce_keys [:id, :metadata, :deploy_manifests, :build_manifests]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          metadata: nil | String.t(),
          deploy_manifests: [BuildDeploy.Type.t()],
          build_manifests: [BuildDeploy.Type.t()]
        }
end
