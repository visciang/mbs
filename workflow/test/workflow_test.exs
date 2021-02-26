defmodule Test.Workflow do
  use ExUnit.Case, async: true

  test "basic workflow exec" do
    workflow_status =
      Workflow.new()
      |> add_jobs()
      |> Workflow.async()
      |> Workflow.await(1_000)

    expected_workflow_execution = [
      job_a1: %{Workflow.workflow_start_job_id() => :ok},
      job_a2: %{Workflow.workflow_start_job_id() => :ok},
      job_a3: %{Workflow.workflow_start_job_id() => :ok},
      job_err1: %{Workflow.workflow_start_job_id() => :ok},
      job_b1: %{job_a1: :ok},
      job_c1: %{job_a1: :ok, job_a2: :ok, job_b1: :ok},
      job_c2: %{job_a3: :ok},
      job_d1: %{job_b1: :ok},
      job_d2: %{job_c1: :ok, job_c2: :ok}
    ]

    assert workflow_status == :error
    assert_workflow_execution(expected_workflow_execution)
  end

  test "job timeout" do
    test_job_fun = gen_test_job_fun(fn -> :ok end)
    test_job_timeout_fun = gen_test_job_fun(fn -> Process.sleep(200) end)

    workflow_status =
      Workflow.new()
      |> Workflow.job(:job_1, test_job_timeout_fun, 100)
      |> Workflow.job(:job_2, test_job_fun)
      |> Workflow.job(:job_3, test_job_fun)
      |> Workflow.flow(:job_1, :job_2)
      |> Workflow.flow(:job_2, :job_3)
      |> Workflow.async()
      |> Workflow.await(1_000)

    expected_workflow_execution = [
      job_1: %{Workflow.workflow_start_job_id() => :ok}
    ]

    assert workflow_status == :error
    assert_workflow_execution(expected_workflow_execution)
  end

  test "bad workflow (deps cycle)" do
    test_job_fun = fn _, _ -> :ok end

    workflow =
      Workflow.new()
      |> Workflow.job(:job_1, test_job_fun)
      |> Workflow.job(:job_2, test_job_fun)
      |> Workflow.depends_on(:job_2, :job_1)
      |> Workflow.depends_on(:job_1, :job_2)

    assert_raise Workflow.Error, fn ->
      Workflow.async(workflow)
    end
  end

  test "bad workflow (unknown job)" do
    test_job_fun = fn _, _ -> :ok end

    workflow =
      Workflow.new()
      |> Workflow.job(:job_1, test_job_fun)

    assert_raise Workflow.Error, fn ->
      Workflow.flow(workflow, :job_1, :unknow_job)
    end

    assert_raise Workflow.Error, fn ->
      Workflow.flow(workflow, :unknow_job, :job_1)
    end
  end

  test "workflow to dot" do
    Workflow.new()
    |> add_jobs()
    |> Workflow.Dot.export()
  end

  defp add_jobs(workflow) do
    test_job_fun = gen_test_job_fun(fn -> :ok end)
    test_job_error_fun = gen_test_job_fun(fn -> raise "Error" end)

    workflow
    |> Workflow.job(:job_a1, test_job_fun)
    |> Workflow.job(:job_a2, test_job_fun)
    |> Workflow.job(:job_a3, test_job_fun)
    |> Workflow.job(:job_b1, test_job_fun)
    |> Workflow.job(:job_c1, test_job_fun)
    |> Workflow.job(:job_c2, test_job_fun)
    |> Workflow.job(:job_d1, test_job_fun)
    |> Workflow.job(:job_d2, test_job_fun)
    |> Workflow.job(:job_err1, test_job_error_fun)
    |> Workflow.job(:job_err2, test_job_fun)
    |> Workflow.flow(:job_a1, [:job_b1, :job_c1])
    |> Workflow.flow(:job_a2, :job_c1)
    |> Workflow.flow(:job_a3, :job_c2)
    |> Workflow.flow(:job_b1, [:job_c1, :job_d1])
    |> Workflow.flow(:job_c1, :job_d2)
    |> Workflow.flow(:job_c2, :job_d2)
    |> Workflow.flow([:job_err1], :job_err2)
  end

  defp gen_test_job_fun(result_fun) do
    test_pid = self()

    fn job_id, upstream_jobs_status ->
      send(test_pid, {job_id, upstream_jobs_status})
      result_fun.()
    end
  end

  defp assert_workflow_execution(expected_workflow_execution) do
    Enum.each(expected_workflow_execution, &assert_received(^&1))

    receive do
      unexpected ->
        flunk("Unexpected workflow execution: #{inspect(unexpected)}")
    after
      0 -> :ok
    end
  end
end
