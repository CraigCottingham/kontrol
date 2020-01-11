defmodule Hadi_1 do
  @moduledoc ~S"""
  * Power up engine
  * Increase throttle until liftoff (legs no longer in contact with ground)
  * Cut engine.
  """

  alias SpaceEx.SpaceCenter
  alias SpaceCenter.{
    Control,
    Flight,
    Leg,
    Parts,
    Vessel
  }

  @doc ~S"""
  """
  def launch(conn) do
    state =
      conn
      |> initialize_state()
      |> initialize_vessel()
      |> Map.put(:throttle, 0.0)

    parent = self()

    legs =
      state.vessel
      |> Vessel.parts()
      |> Parts.legs()
      |> Enum.map(fn leg -> spawn(__MODULE__, :leg_is_grounded, [true, leg, parent]) end)

    Control.activate_next_stage(state.control)

    loop(state)

    Enum.each(legs, fn leg -> Process.exit(leg, :normal) end)
  end

  def loop(%{control: control, flight: flight, vessel: vessel} = state) do
    met = Vessel.met(vessel)
    throttle = Control.throttle(control)
    surface_altitude = Flight.surface_altitude(flight)
    g_force = Flight.g_force(flight)
    vertical_speed = Flight.vertical_speed(flight)

    IO.puts("#{met},#{surface_altitude},#{throttle},#{g_force},#{vertical_speed}")

    receive do
      :airborne ->
        Control.set_throttle(control, 0.0)
      _ ->
        loop(state)
    after
      100 ->
        new_throttle = state.throttle + 0.01
        Control.set_throttle(control, new_throttle)
        loop(%{state | throttle: new_throttle})
    end
  end

  def leg_is_grounded(false, _, parent), do: send(parent, :airborne)
  def leg_is_grounded(true, leg, parent), do: leg_is_grounded(Leg.is_grounded(leg), leg, parent)

  defp initialize_state(conn) do
    vessel = SpaceCenter.active_vessel(conn)
    control = Vessel.control(vessel)
    flight = Vessel.flight(vessel)

    %{conn: conn, control: control, flight: flight, vessel: vessel}
  end

  defp initialize_vessel(%{control: control} = state) do
    Control.set_throttle(control, 0.0)

    state
  end
end

conn = SpaceEx.Connection.connect!(name: "Hadi-1", host: "127.0.0.1")
Hadi_1.launch(conn)
