defmodule Kontrol.DMS do
  @moduledoc false

  @doc ~S"""
  Convert a DMS tuple to a decimal value.

  ## Examples

  iex> Kontrol.DMS.to_latitude({0, 0, 0.00})
  {:ok, 0.0}

  iex> Kontrol.DMS.to_latitude({0, 5, 49.94, :south})
  {:ok, -0.09720555555555556}
  """
  def to_latitude({d, m, s}), do: to_latitude({d, m, s, :north})
  def to_latitude({d, _, _, _}) when (d < -90.0) or (d > 90.0), do: {:error, :out_of_range}
  def to_latitude({d, m, s, :north}), do: {:ok, (d + ((m + (s / 60.0)) / 60.0)) * 1.0}
  def to_latitude({d, m, s, :south}), do: {:ok, (d + ((m + (s / 60.0)) / 60.0)) * -1.0}

  @doc ~S"""
  Convert a DMS tuple to a decimal value.
  The value will be normalized to the range [0.0, 360.0].

  ## Examples

  iex> Kontrol.DMS.to_longitude({0, 0, 0.00})
  {:ok, 0.0}

  iex> Kontrol.DMS.to_longitude({285, 26, 32.36})
  {:ok, 285.44232222222223}

  iex> Kontrol.DMS.to_longitude({74, 33, 27.64, :west})
  {:ok, 285.44232222222223}
  """
  def to_longitude({d, m, s}), do: to_longitude({d, m, s, :east})
  def to_longitude({d, m, s, cardinal}) when (d < 0.0), do: to_longitude({(d + 360.0), m, s, cardinal})
  def to_longitude({d, m, s, cardinal}) when (d > 360.0), do: to_longitude({(d - 360.0), m, s, cardinal})
  def to_longitude({d, m, s, :east}), do: {:ok, (d + ((m + (s / 60.0)) / 60.0))}
  def to_longitude({d, m, s, :west}), do: {:ok, (360.0 - (d + ((m + (s / 60.0)) / 60.0)))}

  @doc ~S"""
  Convert a decimal value representing latitude to a DMS tuple.
  The value must be in the range [-90.0, 90.0].

  ## Examples

  iex> Kontrol.DMS.from_latitude(0.000000)
  {0, 0, 0.00, :north}

  iex> Kontrol.DMS.from_latitude(-0.09720555555555556)
  {0, 5, 49.94000000000001, :south}
  """
  def from_latitude(dms) when (dms < -90.0) or (dms > 90.0), do: {:error, :out_of_range}
  def from_latitude(dms) when (dms < 0.0) do
    {d, m, s} = decimal_to_tuple(abs(dms))
    {d, m, s, :south}
  end
  def from_latitude(dms) do
    {d, m, s} = decimal_to_tuple(abs(dms))
    {d, m, s, :north}
  end

  @doc ~S"""
  Convert a decimal value representing a longitude to a DMS tuple.

  ## Examples

  iex> Kontrol.DMS.from_longitude(0.000000)
  {0, 0, 0.00, :east}

  iex> Kontrol.DMS.from_longitude(285.44232222222223)
  {74, 33, 27.639999999969405, :west}
  """
  def from_longitude(dms) when (dms < -180.0), do: from_longitude(dms + 360.0)
  def from_longitude(dms) when (dms > 180.0), do: from_longitude(dms - 360.0)
  def from_longitude(dms) when (dms < 0.0) do
    {d, m, s} = decimal_to_tuple(abs(dms))
    {d, m, s, :west}
  end
  def from_longitude(dms) do
    {d, m, s} = decimal_to_tuple(abs(dms))
    {d, m, s, :east}
  end

  defp decimal_to_tuple(dms) do
    d = trunc(dms)
    ms = (dms - d) * 60.0
    m = trunc(ms)
    s = (ms - m) * 60.0
    {d, m, s}
  end
end
