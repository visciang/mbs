defprotocol MBS.CLI.Command do
  @spec run(t(), MBS.Config.Data.t(), MBS.CLI.Reporter.t()) :: Dask.await_result()
  def run(args, config, reporter)
end
