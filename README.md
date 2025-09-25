# countly_sdk_dart

Currently supports:

- multi instancing
- pure dart and flutter support
- recording: events, custom requests, metrics, views (autostopped), user properties
- post always, custom headers
- sbs
- consent management, consent requests
- rc download, variants, experiments and enroll calls
- pen, pvn, cvn to views/events
- disabled location request
- manual sessions (auto update)

considerations:

- ui warnings
- user property cache limit (100 key/value pairs)
- user data manipulation methods (array)
- event data types that can be recorded (lists)
- life cycle detection
- duplicate event recording checks
- filtered event keys to sbs
- filter segmentation global and per key
- filtered user properties to sbs
  - print or block
- health checks
- internal event record
- test code coverage
- dart/flutter version support outlines (min support)
