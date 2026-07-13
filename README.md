# tief_test_harness

Flutter integration tests can be verbose and, when running on an emulator, extremely slow.

This package aims to fix at least the latter part by providing a way to run multiple tests across different files in one test file, and the first by creating a testing framework that is uniquely descriptive while being reasonably simple.

## Why

I had the issue of flutter tests on an emulator running build tasks every file. That is slow (~30s on my machine, every time a new test file is loaded). I have too many tests to run to do that. So I decided that a solution which groups tests by reasonably executable files.

## How

The documentation for this package will be lacking early on, but to get started do the following:

- Annotate a function which returns a `ScenarioHarness` (or a Future of one) with `@RegisterHarness("Harness Group", name: "Harness Name")`
- Add Scenarios to the harness via `addScenario`
- Add a file ending with `_test.dart` to your integration test folder
- Annotate a `main()` function in said file with `@GenerateHarnessRegistry('Harness Group')`
- Run `dart run build_runner build`
- Run your tests

I think I forgot nothing. If something is unclear, the doc comments should be relatively complete.

## License

MIT. Look at [LICENSE](LICENSE) for details.

## Contributing

Gladly seen.

## Coffee

I need more coffee. Please.

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/tiefseetauchner)

