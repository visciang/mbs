defmodule MBS.Workflow.Job.RunBuild.Sandbox do
  @moduledoc """
  Sandbox fs for build runs
  """

  alias MBS.Const
  alias MBS.Manifest.BuildDeploy.{Component, Target}

  @spec up(boolean(), Component.t()) :: Component.t()
  def up(false, component), do: component

  def up(true, %Component{files: files, targets: targets} = component) do
    sandbox_dir_ = sandbox_dir(component)
    File.rm_rf!(sandbox_dir_)
    File.mkdir_p!(sandbox_dir_)

    sandbox_files = Enum.map(files, &Path.join(Const.sandbox_dir(), &1))

    sandbox_targets =
      Enum.map(targets, fn
        %Target{type: :docker} = t -> t
        %Target{type: :file} = t -> put_in(t.target, Path.join(Const.sandbox_dir(), t.target))
      end)

    %Component{component | dir: sandbox_dir_, files: sandbox_files, targets: sandbox_targets}
  end

  @spec down(boolean(), Component.t()) :: :ok
  def down(false, _component), do: :ok

  def down(true, %Component{} = component) do
    sandbox_dir_ = sandbox_dir(component)
    File.rm_rf!(sandbox_dir_)
  end

  @spec sandbox_dir(Component.t()) :: Path.t()
  def sandbox_dir(%Component{dir: dir}), do: Path.join(Const.sandbox_dir(), dir)
end
