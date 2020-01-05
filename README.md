# Kontrol

> An exploration of control theory, using
> [Kerbal Space Program](https://www.kerbalspaceprogram.com).

## EXAMPLES

### "Hadi" Series

The Hadi vehicle is about as simple as possible -- an engine, tankage, legs, and a control core.

#### Hadi-1

* test throttle control
* test load sensing on legs

#### Hadi-2

* test throttle control
  * surface altitude to 10 meters
  * coast to max altitude (vertical velocity == 0 m/s)
  * hover for 10 seconds
  * descend at 1 m/s until landing

#### Hadi-(n)

* test inertial navigation system
* telemetry:
  * velocity vector
  * direction vector
  * heading (0..360)
  * pitch (-90..90)
  * roll (-180..180)
