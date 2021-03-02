defimpl MBS.CLI.Command, for: MBS.CLI.Args.Version do
  alias MBS.CLI.Args
  alias MBS.Config

  def run(%Args.Version{}, %Config.Data{}, _reporter) do
    {_, vsn} = :application.get_key(:mbs, :vsn)
    IO.puts(vsn)

    :ok
  end
end
