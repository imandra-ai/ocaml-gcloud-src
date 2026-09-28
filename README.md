OCaml bindings to the Google Cloud Platform APIs
================================================

## Packages

- `gcloud`: runtime-agnostic core. Resource types, and each service
  (`Batch`, `Big_query`, `Storage`, `Pub_sub`, `Kms`, ...) as a functor
  `Make (Async : Async_task_sig.S) (Client : Client_sig.S)` over an async
  runtime and an HTTP client + credential source. No Lwt dependency.
- `gcloud-lwt`: the Lwt + cohttp backend (`Async_task_lwt`,
  `Client_cohttp_lwt`), credential discovery (`Auth`, `Common`), and every
  service module instantiated for Lwt under its usual name, e.g.
  `Gcloud_lwt.Storage.get_object`. Existing callers of `Gcloud.X` become
  `Gcloud_lwt.X`.
- `gcloud-direct`: direct-style backend for OCaml 5 thread pools and effect
  schedulers (moonpool, picos): blocking HTTP via ezcurl/libcurl
  (`Client_ezcurl`), credential discovery (`Auth`, `Common`; service-account
  keys, gcloud ADC, GCE metadata and workload identity federation), and every service module instantiated
  under its usual name, e.g. `Gcloud_direct.Batch.V1.Projects.Locations.Jobs.create`.
  `Async_task_direct.sleep` blocks the thread; the optional
  `gcloud-direct.picos` sub-library provides `Async_task_picos` with a
  fiber-suspending sleep for picos schedulers that support timers (moonpool
  0.11 does not).
- `gcloud-cli`: a small CLI built on `gcloud-lwt`.

To use another runtime, implement the two signatures in `gcloud`
(`Async_task_sig.S`, `Client_sig.S`) and apply the service functors yourself.

## Errors

Every service function returns `('a, (module Gcloud.Error.S)) result`: a
[packed error](https://github.com/imandra-ai/packed) that prints itself
(`Gcloud.Error.pp`) and exposes its value (`Gcloud.Error.value`, a
`Gcloud.Error.Model.t`) for callers that need to react to a particular
failure, e.g. `Api_error (`Not_found, _)`. `Gcloud.Error.status_code` is a
shortcut for the HTTP status of API errors. Wrap it into your own packed error
with `Gcloud.Error.forget` or by repacking the value.

## Development

This is the source repo; it has no vendored dependencies of its own. Build,
test and lock it from the composition root,
[imandra-ai/ocaml-gcloud](https://github.com/imandra-ai/ocaml-gcloud), which
checks this repo out as `src/` next to `vendor/packed`. Consumers that vendor
the bindings should vendor this repo and `packed` side by side.
