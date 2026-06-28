-- Database schema. Added a sessions table while wiring the endpoint.
CREATE TABLE sessions (
  id      INTEGER PRIMARY KEY,
  token   TEXT NOT NULL,
  expires INTEGER NOT NULL
);
