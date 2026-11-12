<a id="readme-top"></a>

<div align="center">

<a href="https://github.com/dev-centr/context7-submit/graphs/contributors"><img src="https://img.shields.io/github/contributors/dev-centr/context7-submit.svg?style=for-the-badge" alt="Contributors"></a>
<a href="https://github.com/dev-centr/context7-submit/network/members"><img src="https://img.shields.io/github/forks/dev-centr/context7-submit.svg?style=for-the-badge" alt="Forks"></a>
<a href="https://github.com/dev-centr/context7-submit/stargazers"><img src="https://img.shields.io/github/stars/dev-centr/context7-submit.svg?style=for-the-badge" alt="Stars"></a>
<a href="https://github.com/dev-centr/context7-submit/issues"><img src="https://img.shields.io/github/issues/dev-centr/context7-submit.svg?style=for-the-badge" alt="Issues"></a>
<a href="https://github.com/dev-centr/context7-submit/blob/main/LICENSE"><img src="https://img.shields.io/github/license/dev-centr/context7-submit.svg?style=for-the-badge" alt="License"></a>

<h1>context7-submit</h1>

<p>Send a documentation source to the Context7 index from a D library or the <code>ctx7-submit</code> program.</p>

<p>
<a href="https://docs.devcentr.org"><strong>Explore the docs »</strong></a>
·
<a href="https://github.com/dev-centr/context7-submit/issues">Report a bug</a>
</p>

</div>

## Contents

- [Why](#why)
- [Install](#install)
- [Usage](#usage)
- [Library use](#library-use)
- [Built with](#built-with)
- [Changelog](#changelog)
- [License](#license)

## Why

Context7's published `ctx7` program can look up documentation and install an agent skill on your machine. It cannot send a new documentation source to the index. The website can. This package does that job under a name that means "send this to Context7," so it is not mistaken for a local install.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Install

From source, with [LDC](https://github.com/ldc-developers/ldc) and [DUB](https://dub.pm):

```sh
dub build -b release
./bin/ctx7-submit --version
```

The package is prepared for [code.dlang.org](https://code.dlang.org). It is not registered there yet. Until it is, depend on a checkout with DUB's `path` and the `library` configuration.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

```sh
export CONTEXT7_API_KEY=ctx7sk-your-key

ctx7-submit https://github.com/owner/repo
ctx7-submit https://dlang.org/spec/spec.html --website-base-url https://dlang.org/spec/
ctx7-submit https://docs.example.com/llms.txt --json
```

`--type` is `github`, `gitlab`, `bitbucket`, `git`, `website`, `openapi`, or `llmstxt`. Leave it out and the program detects the kind from the URL. A documentation site whose host is not a Git forge is a website, including a page several levels under the site root.

`--website-base-url` limits a website crawl to the HTML documentation root. That root is often not the page the site homepage links to.

A private Git token, when you need one, comes from `CONTEXT7_GIT_TOKEN`. The API key and the token are not command arguments. Names and behavior: [docs/environment-variables.adoc](docs/environment-variables.adoc).

Exit codes: `0` submitted or already indexed, `1` the request failed, `2` usage, `3` authentication required, `4` rate limited.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Library use

```sdl
dependency "context7-submit" path="../context7-submit"
subConfiguration "context7-submit" "library"
```

```d
import context7.submit;

auto result = submitSource(SubmitRequest(
    "https://dlang.org/spec/spec.html",
    "website",
    SubmitOptions(false, false, null, false, false, false, false, "https://dlang.org/spec/"),
    environment.get("CONTEXT7_API_KEY", "")
));
```

`submitSource` returns a `SubmitResult`. A source that is already indexed has `ok` and `alreadyExists` set. Pass your own `HttpPost` delegate to test without calling Context7.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Built with

- **Language and build:** [D](https://dlang.org) with [LDC](https://github.com/ldc-developers/ldc) and [DUB](https://dub.pm)
- **HTTP:** Phobos `std.net.curl`
- **Index:** [Context7 Add Library API](https://context7.com/docs/api-guide)

## Changelog

See [CHANGELOG.adoc](CHANGELOG.adoc).

## License

MIT. See [LICENSE](LICENSE).

<p align="right">(<a href="#readme-top">back to top</a>)</p>
