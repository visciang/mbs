defprotocol MBS.CLI.Command do
  @type on_run :: :ok | :error | :timeout

  @spec run(t(), MBS.Config.Data.t()) :: on_run()
  def run(args, config)
end
