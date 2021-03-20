defprotocol MBS.CLI.Command do
  @spec run(t(), MBS.Config.Data.t(), MBS.CLI.Reporter.t()) :: :ok | :error | :timeout
  def run(args, config, reporter)
end
