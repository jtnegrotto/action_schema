# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- **Refinements:** Support the `refine:` option for refining fields
- **Renaming:** Support the `as:` option for renaming fields and associations

## [0.1.1] - 2024-12-09

- **More Closures:** Support procs and lambdas anywhere a block is accepted in the DSL

## [0.1.0] - 2024-12-08

### Added

#### Core Features

- **Rendering:** Render data in controller actions with `schema_for` 
- **Inline schemas:** Define schemas inline in controller actions
- **Controller schemas:** Define reusable schemas directly in controllers with `schema`
- **Class schemas:** Define global schemas in standalone schema classes inheriting from `ActionSchema::Base`

#### Field Definitions

- **Fields:** Define a field with `field` or `fields`
- **Conditional Fields:** Conditionally render fields using `if:` and `unless:`
- **Computed Fields:** Define dynamically calculated fields with `computed`
- **Omitting Fields:** Exclude fields with `omit`

#### Associations

- **Schema Associations:** Nest schemas using `association`. Supports inline, controller, and class schemas.

#### Context & Hooks

- **Contexts:** Pass additional context to schemas
- **Hooks:** Execute code before and after rendering with `before_render` and `after_render`
- **Transformation:** Transform data within hooks with `transform`

#### Configuration

- **Key Transformations:** Define global key transformations with `ActionSchema.configuration.transform_keys`
- **Base Class:** Define your own base class for schemas with `ActionSchema.configuration.base_class`

#### Rails Integration

- **Rails Integration:** Automatically include `ActionSchema::Controller` in Rails controllers via a Railtie.

#### Other

- 100% test coverage
- Comprehensive documentation

[Unreleased]: https://github.com/jtnegrotto/action_schema/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/jtnegrotto/action_schema/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jtnegrotto/action_schema/releases/tag/v0.1.0
