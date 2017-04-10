# Testing Standards and Style Guidelines

This guide outlines standards and best practices for automated testing of GitLab
CE and EE.

It is meant to be an _extension_ of the [thoughtbot testing
styleguide](https://github.com/thoughtbot/guides/tree/master/style/testing). If
this guide defines a rule that contradicts the thoughtbot guide, this guide
takes precedence. Some guidelines may be repeated verbatim to stress their
importance.

## Factories

GitLab uses [factory_girl] as a test fixture replacement.

- Factory definitions live in `spec/factories/`, named using the pluralization
  of their corresponding model (`User` factories are defined in `users.rb`).
- There should be only one top-level factory definition per file.
- FactoryGirl methods are mixed in to all RSpec groups. This means you can (and
  should) call `create(...)` instead of `FactoryGirl.create(...)`.
- Make use of [traits] to clean up definitions and usages.
- When defining a factory, don't define attributes that are not required for the
  resulting record to pass validation.
- When instantiating from a factory, don't supply attributes that aren't
  required by the test.
- Factories don't have to be limited to `ActiveRecord` objects.
  [See example](https://gitlab.com/gitlab-org/gitlab-ce/commit/0b8cefd3b2385a21cfed779bd659978c0402766d).

[factory_girl]: https://github.com/thoughtbot/factory_girl
[traits]: http://www.rubydoc.info/gems/factory_girl/file/GETTING_STARTED.md#Traits

## JavaScript

GitLab uses [Karma] to run its [Jasmine] JavaScript specs. They can be run on
the command line via `bundle exec karma`.

- JavaScript tests live in `spec/javascripts/`, matching the folder structure
  of `app/assets/javascripts/`: `app/assets/javascripts/behaviors/autosize.js`
  has a corresponding `spec/javascripts/behaviors/autosize_spec.js` file.
- Haml fixtures required for JavaScript tests live in
  `spec/javascripts/fixtures`. They should contain the bare minimum amount of
  markup necessary for the test.

    > **Warning:** Keep in mind that a Rails view may change and
    invalidate your test, but everything will still pass because your fixture
    doesn't reflect the latest view. Because of this we encourage you to
    generate fixtures from actual rails views whenever possible.

- Keep in mind that in a CI environment, these tests are run in a headless
  browser and you will not have access to certain APIs, such as
  [`Notification`](https://developer.mozilla.org/en-US/docs/Web/API/notification),
  which will have to be stubbed.

[Karma]: https://github.com/karma-runner/karma
[Jasmine]: https://github.com/jasmine/jasmine

For more information, see the [frontend testing guide](fe_guide/testing.md).

## RSpec

### General Guidelines

- Use a single, top-level `describe ClassName` block.
- Use `described_class` instead of repeating the class name being described.
- Use `.method` to describe class methods and `#method` to describe instance
  methods.
- Use `context` to test branching logic.
- Use multi-line `do...end` blocks for `before` and `after`, even when it would
  fit on a single line.
- Don't `describe` symbols (see [Gotchas](gotchas.md#dont-describe-symbols)).
- Don't assert against the absolute value of a sequence-generated attribute (see [Gotchas](gotchas.md#dont-assert-against-the-absolute-value-of-a-sequence-generated-attribute)).
- Don't supply the `:each` argument to hooks since it's the default.
- Prefer `not_to` to `to_not` (_this is enforced by Rubocop_).
- Try to match the ordering of tests to the ordering within the class.
- Try to follow the [Four-Phase Test][four-phase-test] pattern, using newlines
  to separate phases.
- Try to use `Gitlab.config.gitlab.host` rather than hard coding `'localhost'`

[four-phase-test]: https://robots.thoughtbot.com/four-phase-test

### `let` variables

GitLab's RSpec suite has made extensive use of `let` variables to reduce
duplication. However, this sometimes [comes at the cost of clarity][lets-not],
so we need to set some guidelines for their use going forward:

- `let` variables are preferable to instance variables. Local variables are
  preferable to `let` variables.
- Use `let` to reduce duplication throughout an entire spec file.
- Don't use `let` to define variables used by a single test; define them as
  local variables inside the test's `it` block.
- Don't define a `let` variable inside the top-level `describe` block that's
  only used in a more deeply-nested `context` or `describe` block. Keep the
  definition as close as possible to where it's used.
- Try to avoid overriding the definition of one `let` variable with another.
- Don't define a `let` variable that's only used by the definition of another.
  Use a helper method instead.

[lets-not]: https://robots.thoughtbot.com/lets-not

### Time-sensitive tests

[Timecop](https://github.com/travisjeffery/timecop) is available in our
Ruby-based tests for verifying things that are time-sensitive. Any test that
exercises or verifies something time-sensitive should make use of Timecop to
prevent transient test failures.

Example:

```ruby
it 'is overdue' do
  issue = build(:issue, due_date: Date.tomorrow)

  Timecop.freeze(3.days.from_now) do
    expect(issue).to be_overdue
  end
end
```

### Test speed

GitLab has a massive test suite that, without parallelization, can take more
than an hour to run. It's important that we make an effort to write tests that
are accurate and effective _as well as_ fast.

Here are some things to keep in mind regarding test performance:

- `double` and `spy` are faster than `FactoryGirl.build(...)`
- `FactoryGirl.build(...)` and `.build_stubbed` are faster than `.create`.
- Don't `create` an object when `build`, `build_stubbed`, `attributes_for`,
  `spy`, or `double` will do. Database persistence is slow!
- Use `create(:empty_project)` instead of `create(:project)` when you don't need
  the underlying Git repository. Filesystem operations are slow!
- Don't mark a feature as requiring JavaScript (through `@javascript` in
  Spinach or `js: true` in RSpec) unless it's _actually_ required for the test
  to be valid. Headless browser testing is slow!

### Features / Integration

GitLab uses [rspec-rails feature specs] to test features in a browser
environment. These are [capybara] specs running on the headless [poltergeist]
driver.

- Feature specs live in `spec/features/` and should be named
  `ROLE_ACTION_spec.rb`, such as `user_changes_password_spec.rb`.
- Use only one `feature` block per feature spec file.
- Use scenario titles that describe the success and failure paths.
- Avoid scenario titles that add no information, such as "successfully."
- Avoid scenario titles that repeat the feature title.

[rspec-rails feature specs]: https://github.com/rspec/rspec-rails#feature-specs
[capybara]: https://github.com/teamcapybara/capybara
[poltergeist]: https://github.com/teampoltergeist/poltergeist

## Spinach (feature) tests

GitLab [moved from Cucumber to Spinach](https://github.com/gitlabhq/gitlabhq/pull/1426)
for its feature/integration tests in September 2012.

As of March 2016, we are [trying to avoid adding new Spinach
tests](https://gitlab.com/gitlab-org/gitlab-ce/issues/14121) going forward,
opting for [RSpec feature](#features-integration) specs.

Adding new Spinach scenarios is acceptable _only if_ the new scenario requires
no more than one new `step` definition. If more than that is required, the
test should be re-implemented using RSpec instead.

## Testing Rake Tasks

To make testing Rake tasks a little easier, there is a helper that can be included
in lieu of the standard Spec helper. Instead of `require 'spec_helper'`, use
`require 'rake_helper'`. The helper includes `spec_helper` for you, and configures
a few other things to make testing Rake tasks easier.

At a minimum, requiring the Rake helper will redirect `stdout`, include the
runtime task helpers, and include the `RakeHelpers` Spec support module.

The `RakeHelpers` module exposes a `run_rake_task(<task>)` method to make
executing tasks simple. See `spec/support/rake_helpers.rb` for all available
methods.

Example:

```ruby
require 'rake_helper'

describe 'gitlab:shell rake tasks' do
  before do
    Rake.application.rake_require 'tasks/gitlab/shell'

    stub_warn_user_is_not_gitlab
  end

 describe 'install task' do
    it 'invokes create_hooks task' do
      expect(Rake::Task['gitlab:shell:create_hooks']).to receive(:invoke)

      run_rake_task('gitlab:shell:install')
    end
  end
end
```

---

[Return to Development documentation](README.md)
