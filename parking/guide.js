/**
 * guide.js — the reference half of the app: what each family of NYC parking
 * sign actually permits, with real sign text and the detail that gets people
 * ticketed. Keyed to the category ids in signs.js.
 */

export const GUIDE = [
  {
    id: 'street-cleaning',
    heading: 'Alternate side parking (street cleaning)',
    body:
      'A NO PARKING sign with a broom pictogram and a narrow window — usually 90 minutes, once or twice a week, on one side of the street. Outside that window the space is free. This is the rule the holiday suspension calendar applies to, and nothing else.',
    examples: [
      'NO PARKING (SANITATION BROOM SYMBOL) 11AM-12:30PM TUES & FRI',
      'NO PARKING (SANITATION BROOM SYMBOL) 8AM-9:30AM MON THURS',
    ],
    gotcha:
      'A suspension pauses the sweeping rule only. Meters, no-standing zones and commercial loading zones all keep running on a suspended day.',
  },
  {
    id: 'metered',
    heading: 'Metered parking (1, 2, 3 and 5 hour)',
    body:
      'Green-legend signs reading "1 HOUR METERED PARKING", up through "5 HOUR". The number is the maximum stay, not just how much time you may buy — buying a second session at the same meter does not legally extend it. Payment is at the muni-meter or in the ParkNYC app.',
    examples: [
      '1 HOUR METERED PARKING 8:30AM-7PM EXCEPT SUNDAY',
      '3 HOUR METERED PARKING 8AM-7PM EXCEPT SUNDAY',
      '5 HOUR METERED PARKING 7AM-10PM INCLUDING SUNDAY',
    ],
    gotcha:
      'Outside the posted hours the meter is off, but a second sign on the same pole often bans parking overnight. Read the whole pole, top to bottom — the topmost sign governs the space nearest the pole.',
  },
  {
    id: 'commercial',
    heading: 'Commercial vehicles only / truck loading zones',
    body:
      'Reserved for vehicles with commercial plates that are actively loading or unloading. Typically written as NO STANDING EXCEPT TRUCKS LOADING AND UNLOADING, and often paired with a 3-hour metered commercial rate in Manhattan below 60th Street.',
    examples: [
      'NO STANDING EXCEPT TRUCKS LOADING AND UNLOADING 7AM-6PM MON THRU FRI',
      'COMMERCIAL VEHICLES ONLY 3 HOUR METERED PARKING 7AM-7PM EXCEPT SUNDAY',
    ],
    gotcha:
      'A passenger car is ticketed here even when the block is empty, and even with the flashers on. Commercial plates alone are not enough either — the vehicle has to be actively working.',
  },
  {
    id: 'no-standing',
    heading: 'No standing',
    body:
      'You may stop long enough to let a person in or out. You may not wait for someone, and you may not load goods. Common in front of hotels, hospitals, schools and bus zones.',
    examples: [
      'NO STANDING 7AM-10AM 4PM-7PM MON THRU FRI',
      'NO STANDING EXCEPT AUTHORIZED VEHICLES',
    ],
    gotcha:
      'Sitting behind the wheel does not make it legal. The three levels run NO PARKING (loading allowed) → NO STANDING (passengers only) → NO STOPPING (nothing at all).',
  },
  {
    id: 'no-stopping',
    heading: 'No stopping',
    body:
      'The strictest posting. You may not halt the vehicle for any reason short of a traffic signal or a police direction. Used on bridge approaches, tunnel mouths and rush-hour through lanes.',
    examples: ['NO STOPPING ANYTIME', 'NO STOPPING 7AM-10AM MON THRU FRI'],
    gotcha: 'Rush-hour no-stopping lanes are a favorite for tow trucks, not just ticket writers.',
  },
  {
    id: 'no-parking',
    heading: 'No parking',
    body:
      'You may stand briefly to load or unload goods or passengers, but you may not leave the car. Everything from driveway aprons to school zones lands in this family.',
    examples: ['NO PARKING ANYTIME', 'NO PARKING 8AM-6PM EXCEPT SUNDAY'],
    gotcha:
      'Loading has to be continuous and active. A ticket agent who watches an unattended car for a few minutes can write it.',
  },
  {
    id: 'time-limited',
    heading: 'Time-limited free parking',
    body:
      'Free, but capped — "2 HOUR PARKING 9AM-7PM". Most common outside the metered core, in the outer boroughs.',
    examples: ['2 HOUR PARKING 9AM-7PM EXCEPT SUNDAY', '20 MINUTE PARKING'],
    gotcha:
      'Rolling forward a car length does not reset the clock. Enforcement chalks or photographs the tire position.',
  },
  {
    id: 'bus-stop',
    heading: 'Bus stops',
    body:
      'The zone runs the full length of the marked area, not just the sign post. No standing, no waiting, no exceptions for flashers.',
    examples: ['BUS STOP NO STANDING'],
    gotcha:
      'Bus-stop and bus-lane violations are also caught by camera from the bus itself, so an empty street is no protection.',
  },
  {
    id: 'hydrant',
    heading: 'Fire hydrants',
    body:
      'Fifteen feet on either side of a hydrant, whether or not anything is posted. That is roughly one car length in each direction.',
    examples: ['NO PARKING (FIRE HYDRANT)'],
    gotcha:
      'This one needs no sign at all to be enforceable, and the fine is among the highest routine parking penalties in the city.',
  },
  {
    id: 'permit',
    heading: 'Authorized vehicles and permit zones',
    body:
      'Consulate, agency, press, and building-permit spaces. The sign names who may use it; everyone else is excluded around the clock unless hours are posted.',
    examples: ['NO PARKING EXCEPT AUTHORIZED VEHICLES', 'NO STANDING EXCEPT CONSULATE'],
    gotcha: 'An expired or photocopied placard is treated as no placard.',
  },
  {
    id: 'accessible',
    heading: 'Accessible parking',
    body:
      'Reserved for a valid NYC or New York State permit displayed on the dashboard, with the permit holder present.',
    examples: ['NO PARKING EXCEPT VEHICLES WITH NYC DISABILITY PERMIT'],
    gotcha: 'Using someone else’s permit is a seizure offense, not a ticket.',
  },
  {
    id: 'bike-lane',
    heading: 'Bike lanes and corrals',
    body: 'Protected lanes and on-street bike parking. Standing in one pushes cyclists into moving traffic.',
    examples: ['NO STANDING BICYCLE LANE'],
    gotcha: 'Reported constantly through 311 photo complaints, which enforcement does act on.',
  },
  {
    id: 'carshare',
    heading: 'Car share spaces',
    body: 'Curb spaces dedicated to the DOT car-share program and its member vehicles.',
    examples: ['NO PARKING EXCEPT CAR SHARE VEHICLES'],
    gotcha: 'Marked on the asphalt as well as the pole; the paint is easy to miss at night.',
  },
  {
    id: 'school',
    heading: 'School zones',
    body: 'Restrictions that apply while school is in session, often narrower than they look.',
    examples: ['NO PARKING 7AM-4PM SCHOOL DAYS'],
    gotcha:
      '"School days" is not the same as weekdays — the rule lifts on holidays and over the summer, though enforcement varies.',
  },
  {
    id: 'taxi',
    heading: 'Taxi and for-hire stands',
    body: 'Reserved pickup zones, usually at terminals, stations and large venues.',
    examples: ['NO STANDING TAXI STAND'],
    gotcha: 'Often in force only during posted hours — check for a time range before assuming it is all day.',
  },
];

/** Rules of thumb that are not tied to any one sign family. */
export const RULES_OF_THUMB = [
  'Signs stack vertically and read downward from the pole. The one at the top governs the space closest to the pole; arrows tell you which way each regulation extends.',
  'A double-headed arrow means the rule covers the curb on both sides of the post. A single arrow means it runs only that way, until the next sign.',
  'When two signs conflict, the more restrictive one applies.',
  'Fifteen feet from a hydrant, and never in a crosswalk, sidewalk or bus stop — none of these need a posted sign.',
  'Holiday suspensions pause alternate side only. Meters, no-standing zones and loading zones all keep running.',
];
