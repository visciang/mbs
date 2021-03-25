defprotocol MBS.CLI.Command do
  @spec run(t(), MBS.Config.Data.t()) :: :ok | :error | :timeout
  def run(args, config)
end
