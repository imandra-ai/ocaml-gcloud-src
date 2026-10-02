(** Errors as first-class modules (packed-error). Every service function
    returns [('a, (module S)) result]: the packed error prints itself via
    [pp], and its underlying value ([Model.t]) is recoverable via [value] for
    callers that need to react to, say, a 404. *)

[@@@warning "-39"]

type api_error_item = {
  domain : string;
  reason : string;
  message : string;
  location : string option; [@default None]
  locationType : string option; [@default None]
}
[@@deriving yojson]

type api_error = {
  errors : api_error_item list; [@default []]
  code : int;
  message : string;
}
[@@deriving yojson { strict = false }]

type api_json_error = { error : api_error } [@@deriving yojson]
type api_error_response = Json of api_json_error | Raw of string

[@@@warning "+39"]

module Model = struct
  type t =
    | Auth_error of Auth.error
    | Api_error of Cohttp.Code.status_code * api_error_response
    | Retry_timeout of string
    | Json_parse_error of string * string  (** error, raw json *)
    | Json_transform_error of string * Yojson.Safe.t  (** error, raw json *)
    | Network_error of exn
    | No_project_id
    | Msg of string

  let pp fmt = function
    | Auth_error error ->
        Format.fprintf fmt "Could not authenticate: %a" Auth.pp_error error
    | Api_error (status_code, api_error_response) ->
        Format.fprintf fmt "Gcloud API returned unexpected status code: %s (%s)"
          (Cohttp.Code.string_of_status status_code)
          (match api_error_response with
          | Json j -> j |> api_json_error_to_yojson |> Yojson.Safe.to_string
          | Raw s -> s)
    | Retry_timeout msg -> Format.fprintf fmt "Gcloud retry timeout: %s" msg
    | Json_parse_error (msg, json_str) ->
        Format.fprintf fmt "JSON parse error: %s (%s)" msg json_str
    | Json_transform_error (msg, json) ->
        Format.fprintf fmt "JSON transform error: %s (%s)" msg
          (Yojson.Safe.to_string json)
    | Network_error exn ->
        Format.fprintf fmt "Network error: %s" (Printexc.to_string exn)
    | No_project_id ->
        Format.fprintf fmt "Could not discover the project ID (try setting %s)"
          Auth.Environment_vars.google_project_id
    | Msg s -> Format.fprintf fmt "Msg: %s" s

  module Factory_product = struct
    type nonrec t = t

    module type S = sig
      include Packed_error.S with type t = t
      include Packed_error.With_forget.S with type t = t
      include Packed_error.With_value.S with type t = t
    end

    let make (e : t) (module Base : Packed_error.S with type t = t) =
      (module struct
        include Base

        let e = e
        let forget () = (module Base : Packed_error.S)
      end : S)
  end
end

open struct
  module Error_factory = struct
    include Packed_error_factory.Make.With_pack (Model)
  end
end

module type S = Model.Factory_product.S

type t = Model.t

let pack : t -> (module S) = Error_factory.pack
let value (module E : S) : t = E.e
let forget (module E : S) : (module Packed_error.S) = E.forget ()
let pp fmt (module E : S) = E.pp fmt

(* Constructors *)

let auth_error (e : Auth.error) = pack (Model.Auth_error e)

let api_error (status : Cohttp.Code.status_code) (resp : api_error_response) =
  pack (Model.Api_error (status, resp))

let retry_timeout msg = pack (Model.Retry_timeout msg)
let json_parse_error ~msg ~raw = pack (Model.Json_parse_error (msg, raw))

let json_transform_error ~msg (json : Yojson.Safe.t) =
  pack (Model.Json_transform_error (msg, json))

let network_error (exn : exn) = pack (Model.Network_error exn)
let no_project_id = pack Model.No_project_id
let msg s = pack (Model.Msg s)

(** The HTTP status of an API error, [None] for every other kind. *)
let status_code (e : (module S)) : Cohttp.Code.status_code option =
  match value e with Model.Api_error (s, _) -> Some s | _ -> None

let parse_body_json ?(gzipped = false)
    (transform : Yojson.Safe.t -> ('a, string) result) (body_str : string) :
    ('a, (module S)) result =
  let body =
    if gzipped then
      Ezgzip.decompress body_str
      |> CCResult.map_err (fun _ ->
             json_parse_error ~msg:"gzip decode" ~raw:"<gzipped>")
    else Ok body_str
  in
  let parse_result =
    try body |> CCResult.map Yojson.Safe.from_string with
    | Yojson.Json_error msg -> Error (json_parse_error ~msg ~raw:body_str)
    | e -> Error (json_parse_error ~msg:(Printexc.to_string e) ~raw:body_str)
  in
  parse_result
  |> CCResult.flat_map (fun json ->
         transform json
         |> CCResult.map_err (fun msg -> json_transform_error ~msg json))

let of_response_status_code_and_body ?gzipped
    (status_code : Cohttp.Code.status_code) (body_str : string) :
    ('a, (module S)) result =
  match parse_body_json ?gzipped api_json_error_of_yojson body_str with
  | Ok parsed_error -> Error (api_error status_code (Json parsed_error))
  | Error e -> (
      match value e with
      | Model.Json_parse_error (_, raw) ->
          Error (api_error status_code (Raw raw))
      | _ ->
          Error
            (api_error status_code
               (Raw
                  (Format.asprintf "Error reading api error response: %a" pp e)))
      )
