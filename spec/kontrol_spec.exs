defmodule Kontrol.Spec do
  @moduledoc false

  use ESpec

  # doctest Kontrol

  example_group "getters and setters" do
    before do
      kontrol = Kontrol.new(
        setpoint: 1.0,
        kp: 2.0,
        ki: 3.0,
        kd: 3.5,
        mode: :auto,
        action: :reverse,
        sample_period: 500,
        output_limits: {0.0, 10.0}
      )
      {:shared, kontrol: kontrol}
    end

    it "work as expected" do
      expect(Kontrol.setpoint(shared.kontrol)) |> to(eq(1.0))
      expect(Kontrol.kp(shared.kontrol)) |> to(eq(2.0))
      expect(Kontrol.ki(shared.kontrol)) |> to(eq(3.0))
      expect(Kontrol.kd(shared.kontrol)) |> to(eq(3.5))
      expect(Kontrol.mode(shared.kontrol)) |> to(eq(:auto))
      expect(Kontrol.action(shared.kontrol)) |> to(eq(:reverse))
      expect(Kontrol.sample_period(shared.kontrol)) |> to(eq(500))
      expect(Kontrol.output_limits(shared.kontrol)) |> to(eq({0.0, 10.0}))
    end

    it "invalid action values should be rejected" do
      expect(Kontrol.set_action(shared.kontrol, :direct) |> Kontrol.set_action(:foo) |> Kontrol.action()) |> to(eq(:direct))
      expect(Kontrol.set_action(shared.kontrol, :reverse) |> Kontrol.set_action(:bar) |> Kontrol.action()) |> to(eq(:reverse))
    end
  end

  example_group "controller response" do
    context "when :direct" do
      context "for P" do
        before do
          kontrol = Kontrol.new(
            setpoint: 5.0,
            kp: 0.2,
            mode: :manual
          )
          {:shared, kontrol: kontrol}
        end

        it "converges" do
          {_, steps, _} = Enum.reduce(1..10, {0.0, [], shared.kontrol}, fn _, {input_value, intermediate_values, state} ->
            {:ok, output_value, new_state} = Kontrol.compute(input_value, state)
            next_input_value = input_value + output_value
            {next_input_value, [intermediate_values | [next_input_value]], new_state}
          end)

          steps
          |> List.flatten()
          |> Enum.map(&Float.round(&1, 2))
          |> expect()
          |> to(eq([1.0, 1.8, 2.44, 2.95, 3.36, 3.69, 3.95, 4.16, 4.33, 4.46]))
        end
      end

      context "for PI" do
        before do
          kontrol = Kontrol.new(
            setpoint: 5.0,
            kp: 0.2,
            ki: 1.0,
            mode: :manual,
            action: :direct
          )
          {:shared, kontrol: kontrol}
        end

        it "converges" do
          {_, steps, _} = Enum.reduce(1..10, {0.0, [], shared.kontrol}, fn _, {input_value, intermediate_values, state} ->
            {:ok, output_value, new_state} = Kontrol.compute(input_value, state)
            next_input_value = input_value + output_value
            {next_input_value, [intermediate_values | [next_input_value]], new_state}
          end)

          steps
          |> List.flatten()
          |> Enum.map(&Float.round(&1, 2))
          |> expect()
          |> to(eq([1.5, 3.05, 4.48, 5.68, 6.58, 7.13, 7.36, 7.31, 7.04, 6.62]))
        end
      end
    end

    context "when :reverse" do
      context "for P" do
        before do
          kontrol = Kontrol.new(
            setpoint: 5.0,
            kp: 0.2,
            mode: :manual,
            action: :reverse
          )
          {:shared, kontrol: kontrol}
        end

        it "converges" do
          {_, steps, _} = Enum.reduce(1..10, {0.0, [], shared.kontrol}, fn _, {input_value, intermediate_values, state} ->
            {:ok, output_value, new_state} = Kontrol.compute(input_value, state)
            next_input_value = input_value - output_value
            {next_input_value, [intermediate_values | [next_input_value]], new_state}
          end)

          steps
          |> List.flatten()
          |> Enum.map(&Float.round(&1, 2))
          |> expect()
          |> to(eq([1.0, 1.8, 2.44, 2.95, 3.36, 3.69, 3.95, 4.16, 4.33, 4.46]))
        end
      end

      context "for PI" do
        before do
          kontrol = Kontrol.new(
            setpoint: 5.0,
            kp: 0.2,
            ki: 1.0,
            mode: :manual,
            action: :reverse
          )
          {:shared, kontrol: kontrol}
        end

        it "converges" do
          {_, steps, _} = Enum.reduce(1..10, {0.0, [], shared.kontrol}, fn _, {input_value, intermediate_values, state} ->
            {:ok, output_value, new_state} = Kontrol.compute(input_value, state)
            next_input_value = input_value - output_value
            {next_input_value, [intermediate_values | [next_input_value]], new_state}
          end)

          steps
          |> List.flatten()
          |> Enum.map(&Float.round(&1, 2))
          |> expect()
          |> to(eq([1.5, 3.05, 4.48, 5.68, 6.58, 7.13, 7.36, 7.31, 7.04, 6.62]))
        end
      end
    end
  end
end
