defmodule Mix.Tasks.Run do
  use Mix.Task

  @shortdoc "Run the given file or expression"

  @moduledoc """
  Runs the given file or expression in the context of the application.

  Before running the code, it invokes the `app.start` task which compiles
  and loads your project.

  It is the goal of this task to provide a subset of the functionality
  existent in the `elixir` executable, including setting up the `System.argv`:

      mix run -e Hello.world
      mix run my_script.exs arg1 arg2 arg3

  Many command line options need to be passed to the `elixir` executable
  directly, which can be done as follows:

      elixir --sname hello -S mix run -e "My.code"

  ## Command line options

    * `--config`, `-c`  - loads the given configuration file
    * `--eval`, `-e`    - evaluate the given code
    * `--require`, `-r` - require pattern before running the command
    * `--parallel-require`, `-pr`
                        - requires pattern in parallel
    * `--no-compile`    - do not compile even if files require compilation
    * `--no-deps-check` - do not check dependencies
    * `--no-halt`       - do not halt the system after running the command
    * `--no-start`      - do not start applications after compilation

  """

  @spec run(OptionParser.argv) :: :ok
  def run(args) do
    {opts, head, _} = OptionParser.parse_head(args,
      aliases: [r: :require, pr: :parallel_require, e: :eval, c: :config],
      switches: [parallel_require: :keep, require: :keep, eval: :keep, config: :keep,
                 halt: :boolean, compile: :boolean, deps_check: :boolean, start: :boolean])

    {file, argv} =
      case {Keyword.has_key?(opts, :eval), head} do
        {true, _}  -> {nil, head}
        {_, [h|t]} -> {h, t}
        {_, []}    -> {nil, []}
      end

    System.argv(argv)
    process_config opts

    # Start app after rewriting System.argv,
    # but before requiring and evaling
    Mix.Task.run "app.start", args
    process_load opts

    _ = if file do
      if File.regular?(file) do
        Code.require_file(file)
      else
        Mix.raise "No such file: #{file}"
      end
    end

    unless Keyword.get(opts, :halt, true), do: :timer.sleep(:infinity)
    :ok
  end

  defp process_config(opts) do
    Enum.each opts, fn
      {:config, value} ->
        Mix.Task.run "loadconfig", [value]
      _ ->
        :ok
    end
  end

  defp process_load(opts) do
    Enum.each opts, fn
      {:parallel_require, value} ->
        case filter_patterns(value) do
          [] ->
            Mix.raise "No files matched pattern #{inspect value} given to --parallel-require"
          filtered ->
            Kernel.ParallelRequire.files(filtered)
        end
      {:require, value} ->
        case filter_patterns(value) do
          [] ->
            Mix.raise "No files matched pattern #{inspect value} given to --require"
          filtered ->
            Enum.each(filtered, &Code.require_file(&1))
        end
      {:eval, value} ->
        Code.eval_string(value)
      _ ->
        :ok
    end
  end

  defp filter_patterns(pattern) do
    Enum.filter(Enum.uniq(Path.wildcard(pattern)), &File.regular?(&1))
  end
end
