defmodule MBS.Workflow.Job.RunBuild.Sandbox do
  @moduledoc """
  Sandbox fs for build runs
  """

  alias MBS.Const
  alias MBS.Manifest.BuildDeploy.{Component, Target}

  @spec up(boolean(), Component.t()) :: Component.t()
  def up(false, component), do: component

  def up(true, %Component{files: files, targets: targets} = component) do
    sandbox_dir = get_sandbox_dir(component)
    File.rm_rf!(sandbox_dir)
    File.mkdir_p!(sandbox_dir)

    sandbox_files = Enum.map(files, &Path.join(Const.tmp_dir(), &1))

    sandbox_targets =
      Enum.map(targets, fn
        %Target{type: :docker} = t -> t
        %Target{type: :file} = t -> put_in(t.target, Path.join(Const.tmp_dir(), t.target))
      end)

    %Component{component | dir: sandbox_dir, files: sandbox_files, targets: sandbox_targets}
  end

  @spec down(boolean(), Component.t()) :: :ok
  def down(false, _component), do: :ok

  def down(true, %Component{} = component) do
    sandbox_dir = get_sandbox_dir(component)
    File.rm_rf!(sandbox_dir)
  end

  @spec get_sandbox_dir(Component.t()) :: Path.t()
  defp get_sandbox_dir(%Component{dir: dir}), do: Path.join(Const.tmp_dir(), dir)
end
