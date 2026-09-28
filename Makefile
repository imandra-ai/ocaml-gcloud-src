# This is the source repo. Build and test it from the composition root,
# imandra-ai/ocaml-gcloud, which vendors the non-opam dependencies (packed).

.PHONY: format
format:
	dune build @fmt --auto-promote
