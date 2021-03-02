defprotocol MBS.CLI.Command do
  def run(args, config, reporter)
end
