defmodule MBS.Workflow.Job do
  @moduledoc false

  alias MBS.Manifest.BuildDeploy

  defmodule FunResult do
    @moduledoc false

    defstruct [:cached, :component, :upstream_cached_targets]

    @type t :: %__MODULE__{
            cached: boolean(),
            component: nil | BuildDeploy.Component.t(),
            upstream_cached_targets: MapSet.t(FunResult.UpstreamCachedTarget.t())
          }
  end

  defmodule FunResult.UpstreamCachedTarget do
    @moduledoc false

    defstruct [:component_id, :component_dir, :target]

    @type t :: %__MODULE__{
            component_id: String.t(),
            target: BuildDeploy.Target.t()
          }
  end

  @type upstream_results :: %{String.t() => FunResult.t()}
  @type fun :: (String.t(), upstream_results() -> FunResult.t())
end
