import gleam/dynamic/decode.{type Decoder}
import gleam/string
import shork
import youid/uuid.{type Uuid}

pub fn create_table_query() {
  "
CREATE TABLE IF NOT EXISTS gastos.board (
  `id` VARCHAR(36) NOT NULL,
  `title` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8;
  "
}

pub type Board {
  Board(id: Uuid, title: String)
}

fn row_decoder() -> Decoder(Board) {
  use id <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)

  case uuid.from_string(id) {
    Ok(uuid) -> decode.success(Board(uuid, title))
    Error(_) ->
      decode.failure(Board(uuid.v1(), ""), "Expecting uuid but found " <> id)
  }
}

pub fn create_board(connection, title: String) -> Result(Uuid, CreateBoardError) {
  case string.length(title) > 50 {
    True -> Error(InvalidTitle)
    False -> {
      let id = uuid.v1()
      case
        shork.query(
          "INSERT INTO `gastos`.`board` (`id`, `title`) VALUES (?, ?)",
        )
        |> shork.parameter(shork.text(id |> uuid.to_string))
        |> shork.parameter(shork.text(title))
        |> shork.execute(connection)
      {
        Ok(_) -> Ok(id)
        Error(query_error) -> Error(CreateBoardQueryError(query_error))
      }
    }
  }
}

pub type CreateBoardError {
  InvalidTitle
  CreateBoardQueryError(shork.QueryError)
}

pub fn get_by_uuid(connection, id: Uuid) -> Result(Board, GetBoardError) {
  let return =
    shork.query("SELECT id, title FROM gastos.board WHERE id = ?")
    |> shork.parameter(shork.text(uuid.to_string(id)))
    |> shork.returning(row_decoder())
    |> shork.execute(connection)

  case return {
    Ok(shork.Returend(_, [board])) -> Ok(board)
    Ok(_) -> Error(NotFound)
    Error(query_error) -> Error(GetBoardQueryError(query_error))
  }
}

pub type GetBoardError {
  NotFound
  GetBoardQueryError(shork.QueryError)
}
