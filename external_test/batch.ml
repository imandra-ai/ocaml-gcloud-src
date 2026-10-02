open Gcloud_lwt.Batch.V1

let tests : unit Alcotest_lwt.test_case list =
  [
    (* Requires the Batch API to be enabled in the project *)
    Alcotest_lwt.test_case "projects.locations.jobs.list" `Quick (fun _ () ->
        let open Lwt.Infix in
        Projects.Locations.Jobs.list ~project_id:"imandra-dev"
          ~location:"us-central1" ~page_size:5 ()
        >>= function
        | Ok resp ->
            Alcotest.(check bool)
              "at most page_size jobs" true
              (List.length resp.jobs <= 5)
            |> Lwt.return
        | Error e -> Alcotest.failf "Error:\n%a" Gcloud_lwt.Error.pp e);
  ]
