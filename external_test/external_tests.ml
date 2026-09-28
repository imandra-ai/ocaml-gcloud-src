(* Tests that talk to real GCP: they need credentials with access to the
   imandra-dev project (a GKE cluster, the test-secret secret, the Batch API
   and Error Reporting). Deliberately NOT on [runtest]: run them with
   [dune build @external-tests]. They FAIL without credentials rather than
   skipping, so a test that cannot run never passes silently. *)

let () =
  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (Logs_fmt.reporter ())

let () = Mirage_crypto_rng_unix.initialize (module Mirage_crypto_rng.Fortuna)

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "gcloud external"
       [
         ("stackdriver errors", Stackdriver_errors.tests);
         ("container", Container.tests);
         ("compute", Compute.tests);
         ("secretmanager", Secretmanager.tests);
         ("batch", Batch.tests);
       ]
