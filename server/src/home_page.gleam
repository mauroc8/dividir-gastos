import client_components/redirect
import db/dashboard
import gleam/dynamic
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import helpers/html_extra
import lib/css
import lib/flexbox
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html.{html}
import lustre/event
import lustre/server_component
import shork
import youid/uuid

pub fn page() {
  html_extra.document("Gastos", [
    element.element(
      "lustre-server-component",
      [server_component.route("/home")],
      [],
    ),
  ])
}

pub fn app() {
  lustre.application(init, update, view)
}

// ---

pub opaque type State {
  State(
    dashboard_name: String,
    dashboard_name_error: Option(String),
    is_submitting: Bool,
    connection: shork.Connection,
    redirect_to: Option(String),
  )
}

fn init(connection) {
  #(
    State(
      dashboard_name: "",
      dashboard_name_error: None,
      is_submitting: False,
      connection:,
      redirect_to: None,
    ),
    effect.none(),
  )
}

// ---

pub opaque type Msg {
  BluredDashboardName(value: String)
  Submitted
  CreateBoardResponse(Result(uuid.Uuid, dashboard.CreateBoardError))
}

fn update(state: State, msg: Msg) -> #(State, effect.Effect(Msg)) {
  case msg {
    BluredDashboardName(value) -> {
      #(
        State(..state, dashboard_name: value, dashboard_name_error: None),
        effect.none(),
      )
    }
    Submitted -> {
      case state.dashboard_name {
        "" -> #(
          State(..state, dashboard_name_error: Some("Campo requerido")),
          effect.none(),
        )

        name -> {
          #(
            State(..state, is_submitting: True),
            effect.from(fn(dispatch) {
              dispatch(
                CreateBoardResponse(dashboard.create(state.connection, name)),
              )
            }),
          )
        }
      }
    }
    CreateBoardResponse(res) ->
      case res {
        Ok(id) -> #(
          State(..state, redirect_to: Some("/" <> { id |> uuid.to_string })),
          effect.none(),
        )

        Error(_) -> #(
          State(..state, dashboard_name_error: Some("Hubo un error")),
          effect.none(),
        )
      }
  }
}

// ---

fn view(state: State) {
  let State(dashboard_name_error:, is_submitting:, redirect_to:, ..) = state

  let error_message_id = "dasboard-name-input-error"

  let error_message_attrs = case dashboard_name_error {
    Some(_) -> [
      attribute.attribute("aria-invalid", "true"),
      attribute.attribute("aria-describedby", error_message_id),
    ]
    None -> []
  }

  let input =
    html.input([
      flexbox.fill_width(),
      attribute.value(""),
      attribute.autocomplete("one-time-code"),
      attribute.max("40"),
      server_component.include(["target.value"]),
      attribute.on("blur", blur_handler),
      ..error_message_attrs
    ])

  let error_message = case dashboard_name_error {
    Some(error_message) ->
      html.div(
        [
          attribute.id(error_message_id),
          attribute.style([#("color", "darkred")]),
          attribute.attribute("role", "alert"),
        ],
        [html.text(error_message)],
      )

    None -> html.text("")
  }

  // Performs a client-side redirect through a custom element
  let redirect_element = case redirect_to {
    Some(href) -> redirect.to(href)
    None -> html.text("")
  }

  html_extra.document("Crear tablero | Gastos", [
    html.div(
      [
        attribute.style([#("max-width", "700px"), #("margin", "0 auto")]),
        css.padding(16),
        flexbox.column(),
        flexbox.fill_height(),
        flexbox.center_y(),
        flexbox.spacing(16),
      ],
      [
        html.legend([css.semibold()], [html.text("Crear un tablero nuevo")]),
        html.label([flexbox.column(), flexbox.spacing(8)], [
          html.text("Nombre del tablero"),
          input,
        ]),
        error_message,
        html.button(
          [
            event.on_click(Submitted),
            html_extra.server_side_disabled(is_submitting),
          ],
          [html.text("Crear")],
        ),
      ],
    ),
    redirect_element,
  ])
}

fn blur_handler(event) -> Result(Msg, List(dynamic.DecodeError)) {
  let decoder =
    decode.at(["target", "value"], decode.string)
    |> decode.map(BluredDashboardName)

  decode.run(event, decoder)
  |> html_extra.lustre_decoder_result
}
