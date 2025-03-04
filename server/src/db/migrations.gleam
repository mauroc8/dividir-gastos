import db/dashboard
import shork

pub fn run(connection) {
  let query = dashboard.migrations()

  shork.query(query)
  |> shork.execute(connection)
}
