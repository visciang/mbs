defmodule MBS.CLI.Command.CacheSize do
  @moduledoc false

  defstruct []

  @type t :: %__MODULE__{}
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.CacheSize do
  alias MBS.CLI.Command
  alias MBS.{Config, Const, Docker}

  @separator "  | "

  defmodule Info do
    @moduledoc false

    defstruct [:component, :checksum, :size]

    @type t :: %__MODULE__{
            component: String.t(),
            checksum: String.t(),
            size: non_neg_integer()
          }
  end

  @spec run(Command.CacheSize.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.CacheSize{}, %Config.Data{} = _config, _cwd) do
    run_local_cache()
    run_docker_registry()

    :ok
  end

  @spec run_local_cache :: :ok
  defp run_local_cache do
    infos = info_local_cache()

    IO.puts(IO.ANSI.format([:bright, :green, "\nLocal cache volume:  ", :normal, Const.local_cache_volume(), "\n"]))

    infos
    |> Enum.group_by(& &1.component)
    |> Enum.sort()
    |> Enum.each(&print_files/1)
  end

  @spec run_docker_registry :: :ok
  defp run_docker_registry do
    IO.puts(IO.ANSI.format([:bright, :green, "\n\nLocal docker registry:\n"]))

    {:ok, images} = Docker.image_ls_project()

    images
    |> Enum.group_by(& &1["Repository"])
    |> Enum.sort()
    |> Enum.each(&print_docker/1)
  end

  @spec info_local_cache :: [Info.t()]
  defp info_local_cache do
    Const.local_cache_dir()
    |> fq_ls!()
    |> Enum.flat_map(&info_local_cache_component/1)
  end

  @spec info_local_cache_component(Path.t()) :: [Info.t()]
  defp info_local_cache_component(component_dir) do
    component_dir
    |> fq_ls!()
    |> Enum.map(fn checksum_dir ->
      size =
        checksum_dir
        |> fq_ls!()
        |> Enum.map(&File.lstat!(&1).size)
        |> Enum.sum()

      %Info{
        component: Path.basename(component_dir),
        checksum: Path.basename(checksum_dir),
        size: size
      }
    end)
  end

  @spec fq_ls!(Path.t()) :: [Path.t()]
  defp fq_ls!(base_dir) do
    base_dir
    |> File.ls!()
    |> Enum.map(&Path.join(base_dir, &1))
  end

  @spec print_files({String.t(), [Info.t()]}) :: :ok
  defp print_files({component, infos}) do
    size = infos |> total_size() |> p_mb() |> p_size()

    IO.puts(IO.ANSI.format([size, @separator, :faint, "#{component}"]))

    infos
    |> Enum.sort_by(& &1.checksum)
    |> Enum.each(fn info ->
      size = info.size |> p_mb() |> p_size()
      IO.puts(IO.ANSI.format([:faint, size, :normal, @separator, :faint, "  - #{info.checksum}"]))
    end)
  end

  @spec print_docker({String.t(), [%{String.t() => String.t()}]}) :: :ok
  defp print_docker({component, infos}) do
    IO.puts(IO.ANSI.format([p_size(""), @separator, :faint, "#{component}"]))

    infos
    |> Enum.sort_by(& &1["Tag"])
    |> Enum.each(fn info ->
      size = info["Size"] |> p_size()
      IO.puts(IO.ANSI.format([:faint, size, :normal, @separator, :faint, "  - #{info["Tag"]}"]))
    end)
  end

  @spec total_size([Info.t()]) :: non_neg_integer()
  defp total_size(info) do
    info
    |> Enum.map(& &1.size)
    |> Enum.sum()
  end

  @spec p_mb(non_neg_integer()) :: String.t()
  defp p_mb(bytes) do
    mb = bytes * 1.0e-6
    "#{Float.round(mb, 1)}MB"
  end

  @spec p_size(String.t()) :: String.t()
  defp p_size(size) do
    String.pad_leading(size, 8)
  end
end
