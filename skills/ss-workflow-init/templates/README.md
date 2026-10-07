<h1 align="center">{{PROJECT_NAME}}</h1>

<p align="center">
  {{PROJECT_DESCRIPTION}}
</p>

<p align="center">
  <img alt="Version {{INITIAL_VERSION}}" src="https://img.shields.io/static/v1?label=version&message={{INITIAL_VERSION}}&color=blue">
  <!-- Add more badges once they exist, for example the build status and the license:
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green"></a>
  -->
</p>

<!-- Language links: keep only the languages listed in readme-languages -->
<p align="center">
  English | <a href="README-zh-TW.md">繁體中文</a>
</p>

<!-- A screenshot or a short demo GIF goes here, for example:
<p align="center"><img alt="Screenshot" src="docs/images/screenshot.png" width="720"></p>
-->

<!-- One paragraph: what the project does, and who it is for. -->

- <!-- Key feature 1 -->
- <!-- Key feature 2 -->

<details>
<summary>Table of contents</summary>

- [Getting started](#getting-started)
- [Requirements](#requirements)
- [Documentation](#documentation)
- [Building the source](#building-the-source)
- [Contributing](#contributing)
- [License](#license)

</details>

## Getting started

<!-- For a library: how to add it to a project, and a minimal usage example.
     For an application or firmware: what is needed to run it, and how to download,
     install, or flash it. Tag every code block with its language. -->

## Requirements

<!-- The tools and versions needed to build the project. See the "Toolchain" section
     in AGENTS.md. -->

## Documentation

- Project specification: [docs/{{PROJECT_SLUG}}-spec.md](docs/{{PROJECT_SLUG}}-spec.md)
- Samples: [samples/](samples/)

## Building the source

<!-- Use the language tag of the shell that these commands run in: bash, powershell,
     or bat. -->

```bash
{{BUILD_COMMAND}}
{{TEST_COMMAND}}
```

## Contributing

> [!NOTE]
> This repository uses the ss-workflow process. Every change starts as a request in
> [`reqs/`](reqs/). Development happens on `develop`, and releases are merged into
> `{{MAIN_BRANCH}}` and tagged. See [AGENTS.md](AGENTS.md) for the branching model and
> the commit convention.

## License

<!-- License name and link, e.g. MIT, see [LICENSE](LICENSE). -->
