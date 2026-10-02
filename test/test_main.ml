let () =
  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (Logs_fmt.reporter ())

let () = Mirage_crypto_rng_unix.initialize (module Mirage_crypto_rng.Fortuna)

(* Hermetic tests only: no network, no credentials. Anything that talks to
   real GCP lives in ../external_test. *)
let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "gcloud"
       [
         ("batch", Gcloud_tests.Batch.tests);
         ("batch v1alpha", Gcloud_tests.Batch.alpha_tests);
         ("batch direct", Gcloud_tests.Batch_direct.tests);
       ]
