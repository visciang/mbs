defprotocol MBS.CLI.Command do
  @type on_run :: :ok | :error | :timeout

  @spec run(t(), MBS.Config.Data.t(), Path.t()) :: on_run()
  def run(args, config, cwd)
end
