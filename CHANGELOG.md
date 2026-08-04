# Changelog for DscPipeline

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial Upload

### Fixed

- Fix the `TestConfigData` build task failing with Pester 6, which rejects an
  empty `-TestCases` collection during discovery. The node definition files are
  now looked up through `AllNodes` instead of the non-existing `BuildAgents`
  key, and the roles tests are only created when role definition files exist.
