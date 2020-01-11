defmodule Hadi_2 do
  @moduledoc ~S"""
  * Lift off
  * Ascend to at least 50 meters above surface
  * Hover for at least 10 seconds
  * Descend at 1 m/s until landed
  """

  alias SpaceEx.SpaceCenter
  alias SpaceCenter.{
    CelestialBody,
    Control,
    Flight,
    Leg,
    Orbit,
    Parts,
    ReferenceFrame,
    Vessel
  }

  # NimbleCSV.define(MyParser)

  def launch(conn) do
    state =
      conn
      |> initialize_state()
      |> initialize_ins()
      |> initialize_vessel()
      |> initialize_controllers()
      |> initialize_event_listeners()

    Control.activate_next_stage(state.control)
    Control.set_throttle(state.control, 1.0)

    ascend_to(10.0, Flight.surface_altitude(state.flight), state)
    coast_to_max(Flight.vertical_speed(state.flight), state)
    hover(state)
    descend_until_landed(state)

    Control.set_throttle(state.control, 0.0)
    Enum.each(state.leg_listeners, fn listener -> Process.exit(listener, :normal) end)
  end

  ## these functions need to be public or we get a warning about them being unused
  def leg_is_grounded(leg, grounded_state, parent)

  def leg_is_grounded(leg, nil, parent) do
    send(parent, {:is_grounded, Leg.is_grounded(leg), leg})
    leg_is_grounded(leg, Leg.is_grounded(leg), parent)
  end

  def leg_is_grounded(leg, true, parent) do
    if (Leg.is_grounded(leg)) do
      Process.sleep(1)
      leg_is_grounded(leg, true, parent)
    else
      send(parent, {:is_grounded, false, leg})
      leg_is_grounded(leg, false, parent)
    end
  end

  def leg_is_grounded(leg, false, parent) do
    if (Leg.is_grounded(leg)) do
      send(parent, {:is_grounded, true, leg})
      leg_is_grounded(leg, true, parent)
    else
      Process.sleep(1)
      leg_is_grounded(leg, false, parent)
    end
  end

  defp ascend_to(target_altitude, altitude, %{control: control}) when (altitude >= target_altitude), do: Control.set_throttle(control, 0.0)
  defp ascend_to(target_altitude, _altitude, %{flight: flight} = state), do: ascend_to(target_altitude, Flight.surface_altitude(flight), state)

  defp coast_to_max(vertical_speed, _state) when (vertical_speed < 0.0), do: Process.send_after(self(), :descend, 10_000)
  defp coast_to_max(_, %{flight: flight} = state), do: coast_to_max(Flight.vertical_speed(flight), state)

  defp descend_until_landed(%{control: control, flight: flight, descent_controller: controller} = state) do
    receive do
      {:is_grounded, true, _} ->
        Control.set_throttle(control, 0.0)
        :ok

    after
      0 ->
        Control.set_pitch(control, 0.0)
        Control.set_roll(control, 0.0)

        vertical_speed = Flight.vertical_speed(flight)
        {:ok, throttle_value, controller} = PidController.output(vertical_speed, controller)
        Control.set_throttle(control, throttle_value)
        descend_until_landed(%{state | descent_controller: controller})
    end
  end

  defp hover(%{control: control, flight: flight, hover_controller: controller} = state) do
    receive do
      {:is_grounded, _, _} ->
        # flush out any events related to change of grounded state of the legs
        hover(state)

      :descend ->
        :ok

    after
      0 ->
        Control.set_pitch(control, 0.0)
        Control.set_roll(control, 0.0)

        vertical_speed = Flight.vertical_speed(flight)
        {:ok, throttle_value, controller} = PidController.output(vertical_speed, controller)
        Control.set_throttle(control, throttle_value)
        hover(%{state | hover_controller: controller})
    end
  end

  defp initialize_controllers(state) do
    hover_controller =
      PidController.new(kp: 0.1, ki: 0.001)
      |> PidController.set_setpoint(0.0)

    descent_controller =
      PidController.new(kp: 0.1, ki: 0.001)
      |> PidController.set_setpoint(-1.0)

    state
    |> Map.put(:hover_controller, hover_controller)
    |> Map.put(:descent_controller, descent_controller)
  end

  defp initialize_event_listeners(state) do
    parent = self()

    listeners =
      state.vessel
      |> Vessel.parts()
      |> Parts.legs()
      |> Enum.map(fn leg -> spawn(__MODULE__, :leg_is_grounded, [leg, nil, parent]) end)

    Map.put(state, :leg_listeners, listeners)
  end

  defp initialize_ins(%{conn: conn, flight: flight, vessel: vessel} = state) do
    ## create a reference frame fixed relative to the celestial body, and oriented with the surface of the body
    ##   * the origin is at the surface, on the vector from the center of the body to the vessel's center of mass
    ##   * the axes rotate with the north and up directions on the surface of the body
    ##   * the x-axis points in the zenith direction (upwards, normal to the body being orbited, from the center of the body towards the center of mass of the vessel)
    ##   * the y-axis points northwards towards the astronomical horizon (north, and tangential to the surface of the body – the direction in which a compass would point when on the surface)
    ##   * the z-axis points eastwards towards the astronomical horizon (east, and tangential to the surface of the body – east on a compass when on the surface)

    body =
      vessel
      |> Vessel.orbit()
      |> Orbit.body()

    latitude = Flight.latitude(flight)
    longitude = Flight.longitude(flight)
    altitude = Flight.mean_altitude(flight)

    position = CelestialBody.surface_position(body, latitude, longitude, CelestialBody.reference_frame(body))

    q_longitude = {
      0.0,
      :math.sin(longitude * -0.5 * :math.pi() / 180.0),
      0.0,
      :math.cos(longitude * -0.5 * :math.pi() / 180.0)
    }
    q_latitude = {
      0.0,
      0.0,
      :math.sin(latitude * 0.5 * :math.pi() / 180.0),
      :math.cos(latitude * 0.5 * :math.pi() / 180.0)
    }

    frame = ReferenceFrame.create_relative(
      conn,
      ReferenceFrame.create_relative(
        conn,
        ReferenceFrame.create_relative(
          conn,
          CelestialBody.reference_frame(body),
          position: position,
          rotation: q_longitude
        ),
        rotation: q_latitude
      ),
      position: {altitude, 0.0, 0.0}
    )

    state
    |> Map.put(:reference_frame, frame)
    |> Map.put(:flight, Vessel.flight(vessel, reference_frame: frame))
  end

  defp initialize_state(conn) do
    vessel = SpaceCenter.active_vessel(conn)
    control = Vessel.control(vessel)
    flight = Vessel.flight(vessel)

    Control.set_input_mode(control, :override)

    %{conn: conn, control: control, controller: nil, flight: flight, reference_frame: nil, vessel: vessel}
  end

  defp initialize_vessel(%{control: control} = state) do
    Control.set_throttle(control, 0.0)

    state
  end
end

conn = SpaceEx.Connection.connect!(name: "Hadi-2", host: "127.0.0.1")
Hadi_2.launch(conn)
