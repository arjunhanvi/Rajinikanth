# Controls overhaul: on foot and driving (v0.7.0)

**Status:** implemented and tested in simulation, with injected touch events on the real touch-pad code, in the running game.

**Not yet tested on a real touchscreen.** No phone is connected to the development session. Install `build/bigbanglore_controls_test.apk` and go through the checklist at the end.

The opening, story, saves, character systems and world are unchanged. Settings keep their old values; the only migration is that steering moves once from the old default (arrow buttons) to the new steering pad.

## On foot

**Movement stick (left):**
- A floating stick: it appears where your thumb lands.
- 12% dead zone, then a response curve: fine control near the centre, full speed at the rim.
- Jitter filter: small wobbles in direction are smoothed slowly, real turns follow quickly.
- If your thumb drifts past the ring, the base follows it, so the stick never slips off.

**Walk and run:** a push past 85% (marked by a faint inner ring) runs. A lighter push walks, with speed proportional to the push. The old RUN button is gone.

**RUN LOCK:**
1. Hold the stick straight forward (within 25°) at full push for **0.6 s**. The hold time can be set from 0.4 to 1.2 s in Settings. An amber arc fills above the stick while you hold.
2. A **RUN LOCK** chip appears above the stick, never under the thumb. Engage it by sliding your thumb onto it and letting go, or by tapping it within 2 s.
3. **While locked:** he keeps running with your thumb lifted. Touching the stick steers him without cancelling the lock. The ring turns amber and the chip reads RUN LOCK ON ✕.
4. **Cancel** by any of:
   - tapping the chip;
   - pulling the stick firmly back;
   - running into a wall (blocked for 0.3 s);
   - dialogue or a cutscene, getting into a vehicle, the bus, riding pillion, or pausing.

**Right side:**
- Camera drag is smoothed, with acceleration for fast swipes and a short glide after you let go. Horizontal and vertical sensitivity are set separately.
- The camera uses a sphere cast so it doesn't clip into walls.
- One amber contextual action button (Enter, Talk, …) appears only when there is something to do.
- Small line-icon buttons for Jump, Crouch and Hit.

**Settings** (saved with your other settings):
- camera sensitivity, horizontal and vertical;
- invert Y;
- stick size;
- button size;
- HUD opacity;
- left-handed layout;
- RUN LOCK hold time;
- vibration;
- show touches (for testing);
- reset controls.

### Simulated touch test: 18/18 pass (`tools/dev/Harness.gd`, scenario `controls`)

| Check | Result |
|---|---|
| Half push walks; full push runs | pass |
| 0.3 s at full push does not offer the lock; **8 quick upward flicks never offer it** | pass |
| Full push sideways does not offer the lock | pass |
| A 0.8 s forward hold offers the lock | pass |
| Slide onto the chip and release: lock on | pass |
| Keeps running with no thumb on the stick (4.2 m/s) | pass |
| Steers right while locked (turned 1.24 rad) | pass |
| Pull back cancels; he stops after letting go | pass |
| Chip stays offered for a moment after letting go; a tap engages it; a second tap cancels | pass |
| A dialogue lock ends it; running into a wall ends it | pass |
| A 240 px camera drag turns the camera 1.33 rad, smoothly | pass |

Screenshots: `docs/controls/c01…c08*.jpg` and `onfoot_states_sheet.jpg`.

## Driving

**HUD:**
- An analogue **steering pad** on the left: your thumb lands anywhere, and left/right offset steers, with a third of the pad's width giving full lock. Centred on release.
  - Other steering options in Settings: joystick, arrow buttons, tilt (tilt is untested on a device).
- Tall **accelerator** and **brake** pedals on the right. How hard you press depends on where you touch the pedal: low is a light press, high is full.
- **Holding the brake at a standstill engages reverse.** "R" shows, the brake pedal turns red and reads REVERSE, and holding it backs you up. The accelerator returns to drive.
- A large horn, a handbrake (P), exit and radio buttons.
- A speed and gear gauge beside the steering pad.

**Handling** (`scripts/vehicles/Handling.gd`), a profile per vehicle class:
- wheelbase;
- steering lock and how it tightens with speed;
- steering speed and return speed;
- engine curve with gear changes;
- brakes;
- tyre grip (understeer at the limit; the handbrake lets the rear slide);
- suspension frequency and damping;
- roll or lean, and pitch.

**Suspension, for all vehicles:**
- Raycasts under each wheel put the body on the real road surface. Previously, vehicles sat 9 cm inside the road.
- Springs and dampers on body height, pitch and roll; dive under braking, squat on acceleration, roll in corners; two-wheelers lean into turns.
- A hard tyre-contact constraint: no wheel can end up below the road.

**Camera:** a chase camera per class (closer and lower for two-wheelers). It looks ahead into the turn and along the velocity, and its distance and field of view grow with speed. Sphere-cast collision.

**Not changed:** traffic and the opening still move vehicles directly. They gain the suspension body motion only.

### Simulated driving test: 42/42 pass (`tools/dev/Harness.gd`, scenario `driving`, Outer Ring Road)

| Class | 0–40 km/h | Speed after 8 s | Turning radius at 25 km/h | Body | Stop from 40 km/h* | Reverse | Speed breaker (16 cm) |
|---|---|---|---|---|---|---|---|
| Saloon (car) | 4.5 s | 60 km/h | 7.5 m (grip-limited) | roll 5.7° | 8.7 m | yes | rides up, settles |
| Hatchback | 4.2 s | 61 km/h | 7.0 m | roll 5.2° | 7.8 m | yes | rides up, settles |
| Auto-rickshaw | top speed ~40 km/h | 40 km/h | 11.0 m | roll 5.4° | 10.5 m | yes | rides up, settles |
| Motorcycle | 3.2 s | 73 km/h | 6.3 m | lean 37° | 8.4 m | yes | rides up, settles |
| Scooter | 4.8 s | 52 km/h | 7.3 m | lean 34° | 9.8 m | yes | rides up, settles |
| City bus | — | 31 km/h | 14.0 m | roll 3.0° | 9.9 m (from 36 km/h) | yes | rides up, settles |
| Lorry | — | 28 km/h | 14.3 m | roll 2.8° | 8.8 m (from 33 km/h) | yes | rides up, settles |

\*The bus and lorry were braked from their test speed (36 and 33 km/h).

The saloon's steering, braking and reverse were driven through real injected touches on the pedals and the steering pad.

Screenshots: `docs/controls/d_*.jpg` and `driving_sheet.jpg`.

### Known limitations

- The wheels are part of the body mesh. They follow the suspension, but they don't visibly spin or steer.
- The motorcycle rider's pose looks wrong in a hard lean.
- An auto-rickshaw can't tip over.
- There is no rigid-body collision response. Crashes still use the old slide-and-slow behaviour.

## On-device checklist

Please test on your phone, with **Settings → Show touches (testing)** turned on so the green and red dots show what the game receives.

**On foot:**
1. Walk slowly in circles with a light push. The direction should not wobble.
2. Push fully to run. Quick upward flicks must **never** show the RUN LOCK chip.
3. Hold forward for about half a second. The amber arc fills and the chip appears above the stick. Slide onto it and let go. He keeps running.
4. While locked, touch the stick and steer. Then pull back to cancel, and also try tapping the chip to cancel.
5. While locked, run into a wall. The lock should end.
6. Drag the camera slowly and quickly, horizontally and vertically.
7. Change the stick size, HUD opacity, left-handed layout and RUN LOCK hold time. Restart the game and check they were kept.

**Driving:**
1. Get into a car, auto, scooter and bus in turn. Steer with the pad and press the pedals at different heights.
2. Brake to a stop, keep holding: it should go into reverse. Press the accelerator: it should go back to drive.
3. Take sharp turns at speed, use the handbrake, and drive over kerbs.
4. Try tilt steering in Settings. It needs calibration on a real device; tell me how it feels.

Please report anything that feels wrong: dead zone, stick size, hold time, steering speed or pedal response. Everything is a tunable number.
