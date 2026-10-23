<h1 align="center">{{WORKSPACE_NAME}}</h1>

<p align="center">
  {{WORKSPACE_DESCRIPTION}}
</p>

<!-- Badges: the workspace has no version of its own; each project has its own
     version and badges in its repository. Add workspace badges once they exist, for
     example the license:
<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green"></a>
</p>
-->

<!-- Language links: keep only the languages listed in readme-languages -->
<p align="center">
  English | <a href="README-zh-TW.md">繁體中文</a>
</p>

<!-- One paragraph: what the projects of this workspace do together, and who they are for. -->

- <!-- Key point 1 -->
- <!-- Key point 2 -->

<details>
<summary>Table of contents</summary>

- [Projects](#projects)
- [Getting started](#getting-started)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

</details>

## Projects

Each project is a git submodule in `projects/`, with its own repository, versions, and
README.

| Project | Path | Repository | Spec | Description |
|---------|------|------------|------|-------------|
{{PROJECT_ROWS}}

## Getting started

Clone the workspace with its projects:

```bash
git clone --recurse-submodules <workspace URL>
```

> [!NOTE]
> In a clone without the projects, run `git submodule update --init --recursive`.
> The build of each project is described in its own README.

## Documentation

- Overview of the workspace: [docs/overview.md](docs/overview.md)
- The spec of each project: `docs/<project>/spec.md`, linked in [Projects](#projects)
- Requests: [reqs/](reqs/)

## Contributing

> [!NOTE]
> This workspace uses the ss-workflow process. Every change starts as a request in
> [`reqs/`](reqs/). The code is committed in the project repositories, and the
> workspace records the requests and which project commits they produced.
> Development happens on `develop`, and each project is released on its own. See
> [AGENTS.md](AGENTS.md) for the branching model and the commit convention.

## License

<!-- License name and link, e.g. MIT, see [LICENSE](LICENSE). -->
