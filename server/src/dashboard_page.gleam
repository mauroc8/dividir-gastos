import client_components/document_title
import client_components/redirect
import db/dashboard
import gleam/dict
import gleam/dynamic
import gleam/option.{type Option, None, Some}
import helpers/html_extra
import lib/flexbox
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/server_component
import shork
import youid/uuid

pub fn document(id: String) {
  html_extra.document("Cargando… | Gastos", [
    element.element(
      "lustre-server-component",
      [
        server_component.route("/dashboard"),
        attribute.attribute("dashboard-id", id),
      ],
      [],
    ),
  ])
}

pub fn app() {
  lustre.component(init, update, view, on_attribute_change())
}

// ---

/// Receives the `uuid` via attributes
fn on_attribute_change() {
  dict.from_list([
    #("dashboard-id", fn(dynamic) {
      case dynamic.string(dynamic) {
        Ok(string_id) -> Ok(GotUuid(string_id))
        Error(error) -> Error(error)
      }
    }),
  ])
}

// ---

pub opaque type State {
  State(
    connection: shork.Connection,
    redirect_to: Option(String),
    dashboard: BoardStatus,
  )
}

fn init(connection) {
  #(
    State(connection:, redirect_to: None, dashboard: LoadingBoard),
    effect.none(),
  )
}

type BoardStatus {
  LoadingBoard
  LoadBoardError(dashboard.GetBoardError)
  LoadedBoard(dashboard.Dashboard)
}

// ---

pub opaque type Msg {
  GotUuid(id: String)
  ReceivedBoardResponse(
    result: Result(dashboard.Dashboard, dashboard.GetBoardError),
  )
}

fn update(state: State, msg: Msg) -> #(State, effect.Effect(Msg)) {
  case msg {
    GotUuid(id) ->
      case uuid.from_string(id) {
        Ok(id) -> #(state, fetch_dashboard(state.connection, id))
        Error(_) -> #(State(..state, redirect_to: Some("/")), effect.none())
      }
    ReceivedBoardResponse(result) ->
      case result {
        Ok(dashboard) -> #(
          State(..state, dashboard: LoadedBoard(dashboard)),
          effect.none(),
        )
        Error(board_load_error) -> #(
          State(..state, dashboard: LoadBoardError(board_load_error)),
          effect.none(),
        )
      }
  }
}

fn fetch_dashboard(connection, id) {
  effect.from(fn(dispatch) {
    dispatch(ReceivedBoardResponse(dashboard.get_by_uuid(connection, id)))
  })
}

// ---

fn view(state) {
  let State(redirect_to:, dashboard:, ..) = state

  let redirect_component = case redirect_to {
    Some(href) -> redirect.to(href)
    None -> html.text("")
  }

  let title_component =
    document_title.value(case dashboard {
      LoadingBoard -> "Cargando… | Gastos"
      LoadedBoard(board_data) -> board_data.title <> " | Gastos"
      LoadBoardError(_) -> "Error | Gastos"
    })

  html.main(
    [
      flexbox.column(),
      flexbox.center_x(),
      flexbox.center_y(),
      attribute.style([#("max-width", "700px"), #("margin", "0 auto")]),
    ],
    [
      title_component,
      redirect_component,
      html.text(case dashboard {
        LoadingBoard -> "Cargando…"
        LoadedBoard(board_data) -> board_data.title
        LoadBoardError(_) -> "Error"
      }),
    ],
  )
}
