defmodule Kontrol do
  @moduledoc """
  Documentation for Kontrol.
  """

  # default prop_mode to :p_on_e
  def new(initial_values \\ []) do
    %{
      setpoint: 0.0,
      kp: 0.0,
      ki: 0.0,
      kd: 0.0,
      # proportional_mode:
      action: :direct,
      mode: :manual,
      sample_period: 100,
      output_limits: {nil, nil},
      last_sample_time: System.monotonic_time(:millisecond),
      error_sum: 0.0,
      last_input: 0.0,
      last_output: nil,
      p_term: 0.0,
      i_term: 0.0,
      d_term: 0.0
    }
    |> set_setpoint(Keyword.get(initial_values, :setpoint))
    |> set_kp(Keyword.get(initial_values, :kp))
    |> set_ki(Keyword.get(initial_values, :ki))
    |> set_kd(Keyword.get(initial_values, :kd))
    # |> set_proportional_mode(Keyword.get(initial_values, :proportional_mode))
    |> set_action(Keyword.get(initial_values, :action))
    |> set_mode(Keyword.get(initial_values, :mode))
    |> set_sample_period(Keyword.get(initial_values, :sample_period))
    |> set_output_limits(Keyword.get(initial_values, :output_limits))
  end

  def setpoint(state), do: state.setpoint
  def kp(state), do: state.kp
  def ki(state), do: state.ki
  def kd(state), do: state.kd
  # def proportional_mode(state), do: {:ok, state.proportional_mode}
  def action(state), do: state.action
  def mode(state), do: state.mode
  def sample_period(state), do: state.sample_period
  def output_limits(state), do: state.output_limits

  def set_setpoint(state, nil), do: state
  def set_setpoint(state, new_setpoint), do: %{state | setpoint: new_setpoint}

  def set_kp(state, nil), do: state
  def set_kp(state, new_kp), do: %{state | kp: new_kp}

  def set_ki(state, nil), do: state
  def set_ki(state, new_ki), do: %{state | ki: new_ki} #  * state.sample_period / 1000.0 ?

  def set_kd(state, nil), do: state
  def set_kd(state, new_kd), do: %{state | kd: new_kd} #  * state.sample_period / 1000.0 ?

  # def set_proportional_mode(new_prop_mode, state), do: %{state | proportional_mode: new_prop_mode}

  def set_action(state, new_action) when new_action in [:direct, :reverse], do: %{state | action: new_action}
  def set_action(state, _), do: state

  def set_mode(%{mode: :manual} = state, :auto) do
    # switch from manual to auto
    %{state | mode: :auto}
  end

  def set_mode(state, new_mode) do
    %{state | mode: new_mode}
  end

  @doc ~S"""
  Sets the sample period.
  If fewer than this many milliseconds have elapsed since the last time compute/0 was called,
  computation will be skipped.
  100 by default?
  """
  def set_sample_period(state, nil), do: state
  def set_sample_period(state, new_sample_period), do: %{state | sample_period: new_sample_period}
    # %{state | sample_period: new_sample_period, ki: state.ki * (new_sample_period / state.sample_period), kd: state.kd / (new_sample_period / state.sample_period)}

  @doc ~S"""
  Clamps the output to a specified range.
  """
  def set_output_limits(state, {nil, nil} = new_output_limits), do: %{state | output_limits: new_output_limits}
  def set_output_limits(state, {nil, new_max} = new_output_limits) when is_integer(new_max) or is_float(new_max), do: %{state | output_limits: new_output_limits}
  def set_output_limits(state, {new_min, nil} = new_output_limits) when is_integer(new_min) or is_float(new_min), do: %{state | output_limits: new_output_limits}
  def set_output_limits(state, {new_min, new_max} = new_output_limits) when is_integer(new_min) and is_integer(new_max), do: %{state | output_limits: new_output_limits}
  def set_output_limits(state, {new_min, new_max} = new_output_limits) when is_float(new_min) and is_float(new_max), do: %{state | output_limits: new_output_limits}
  def set_output_limits(state, _), do: state

  @doc ~S"""
  Performs the PID calculation.

  Returns {:ok, new_output, state} or {:idle, old_output, state}.

  ## `mode: :manual`

  When `mode` is `:manual`, the controller assumes that a known fixed interval of time
  (set by `set_sample_period/2`) has elapsed since the last calculation.

  ## `mode: :auto`

  When `mode` is `:auto`, the controller keeps track of the time elapsed since the
  last calculation, and adjusts the Ki and Kd coefficients accordingly.
  """
  def compute(input, %{mode: :manual} = state) do
    {output, state} = compute_output(input, state.sample_period, state)
    {:ok, output, state}
  end

  def compute(input, %{mode: :auto} = state) do
    now = System.monotonic_time(:millisecond)
    {output, state} = compute_output(input, (now - state.last_sample_time), state)
    {:ok, output, %{state | last_sample_time: now}}
  end

  defp action_multiplier(:direct), do: 1.0
  defp action_multiplier(:reverse), do: -1.0

  defp clamp(value, %{output_limits: {nil, nil}}), do: value
  defp clamp(value, %{output_limits: {nil, max}}) when (value <= max), do: value
  defp clamp(value, %{output_limits: {min, nil}}) when (value >= min), do: value
  defp clamp(value, %{output_limits: {min, _}}) when (value < min), do: min
  defp clamp(value, %{output_limits: {_, max}}) when (value > max), do: max

  defp compute_output(input, sample_interval, state) do
    error = state.setpoint - input

    p_term = state.kp * action_multiplier(state.action) * error
    i_term = state.ki * action_multiplier(state.action) * (state.error_sum + error) * sample_interval / 1_000
    d_term = state.kd * action_multiplier(state.action) * (input - state.last_input) * 1_000 / sample_interval

    output = clamp((p_term + i_term + d_term), state)

    {output, %{state |
      last_input: input,
      last_output: output,
      error_sum: clamp((state.error_sum + error), state),
      p_term: p_term,
      i_term: i_term,
      d_term: d_term
    }}
  end
end
