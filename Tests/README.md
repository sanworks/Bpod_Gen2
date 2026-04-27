# Bpod testing
This folder contains the testing of Bpod, which can be run like so:
1. `Bpod`
2. navigate into `Tests/` and `runAllTests`

Users can run all of the tests on their setup when, after having run `Bpod` to add necessary files to the Path, the user runs `runAllTests` from within this folder.

The tests contained in `BpodLib` also run on GitHub Actions in pull requests made to `develop` and `master`.
However, because of `BpodSystem`'s integration with GUI elements, GitHub cannot run tests that use `BpodSystem`.
For this reason, any tests that require the actual `BpodSystem` should go in `BpodSystemTests/` to be run locally.

If `BpodSystem` does not exist in the workspace, the tests in `BpodSystemTests/` will call `Bpod EMU`.
Otherwise the user can call `runAllTests` with `BpodSystem` in the workspace and the tests will use that `BpodSystem` (i.e. to run tests with a non-emulated `BpodSystem`).