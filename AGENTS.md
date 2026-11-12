# context7-submit agent notes

Org rules: `dev-centr/agent-rules`. This file only adds repo facts.

- D / DUB. `dub test --compiler=ldc2` runs the unit tests. `dub build --compiler=ldc2` writes `bin/ctx7-submit`.
- The `library` configuration is what other programs import (`import context7.submit`). The `application` configuration is the program.
- Never print `CONTEXT7_API_KEY` or `CONTEXT7_GIT_TOKEN`. They are environment variables, not arguments.
- Version lives in `source/context7/submit/version_.d` and `dub.sdl`. Keep them the same.
- Changelog: root `CHANGELOG.adoc` and `changelog-details/` (no Antora site in this repo).
- Prepared for code.dlang.org. Do not publish unless asked.
