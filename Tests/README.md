# Bpod testing
This folder contains the testing of Bpod. `runBpodTests` requires two things:
1. `Bpod` has been run (to add the necessary items into Path)
2. The folder Tests/ is accessible (either `addpath('Tests')` or Current Directory is in it)

- `BpodLib/` is unit-tests for `+BpodLib`.
- `Integrations/` uses a `BpodSystem` without its GUI elements to run non-GUI integration tests.
- `GUI_Tests/` includes tests for anything involving GUIs.

The BpodLib and Integrations tests run on GitHub Actions in pull requests made to `develop` and `master`. However, GitHub Actions doesn't support GUI elements in its testing and so GUI_Tests can only be run locally.

## Running with emulator vs real machine
Both the tests in `Integrations/` and `GUI_Tests/` can optionally be run with an existing `BpodSystem`. If there is no active `BpodSystem` they initialize an emulator. To run tests with real hardware, calling `Bpod` and then `runBpodTests` will make tests use the `BpodSystem` that the user initialised.
