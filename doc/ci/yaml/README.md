# Configuration of your jobs with .gitlab-ci.yml

This document describes the usage of `.gitlab-ci.yml`, the file that is used by
GitLab Runner to manage your project's jobs.

If you want a quick introduction to GitLab CI, follow our
[quick start guide](../quick_start/README.md).

## .gitlab-ci.yml

From version 7.12, GitLab CI uses a [YAML](https://en.wikipedia.org/wiki/YAML)
file (`.gitlab-ci.yml`) for the project configuration. It is placed in the root
of your repository and contains definitions of how your project should be built.

The YAML file defines a set of jobs with constraints stating when they should
be run. The jobs are defined as top-level elements with a name and always have
to contain at least the `script` clause:

```yaml
job1:
  script: "execute-script-for-job1"

job2:
  script: "execute-script-for-job2"
```

The above example is the simplest possible CI configuration with two separate
jobs, where each of the jobs executes a different command.

Of course a command can execute code directly (`./configure;make;make install`)
or run a script (`test.sh`) in the repository.

Jobs are picked up by [Runners](../runners/README.md) and executed within the
environment of the Runner. What is important, is that each job is run
independently from each other.

The YAML syntax allows for using more complex job specifications than in the
above example:

```yaml
image: ruby:2.1
services:
  - postgres

before_script:
  - bundle install

after_script:
  - rm secrets

stages:
  - build
  - test
  - deploy

job1:
  stage: build
  script:
    - execute-script-for-job1
  only:
    - master
  tags:
    - docker
```

There are a few reserved `keywords` that **cannot** be used as job names:

| Keyword       | Required | Description |
|---------------|----------|-------------|
| image         | no | Use docker image, covered in [Use Docker](../docker/README.md) |
| services      | no | Use docker services, covered in [Use Docker](../docker/README.md) |
| stages        | no | Define build stages |
| types         | no | Alias for `stages` (deprecated) |
| before_script | no | Define commands that run before each job's script |
| after_script  | no | Define commands that run after each job's script |
| variables     | no | Define build variables |
| cache         | no | Define list of files that should be cached between subsequent runs |

### image and services

This allows to specify a custom Docker image and a list of services that can be
used for time of the job. The configuration of this feature is covered in
[a separate document](../docker/README.md).

### before_script

`before_script` is used to define the command that should be run before all
jobs, including deploy jobs, but after the restoration of artifacts. This can
be an array or a multi-line string.

### after_script

> Introduced in GitLab 8.7 and requires Gitlab Runner v1.2

`after_script` is used to define the command that will be run after for all
jobs. This has to be an array or a multi-line string.

### stages

`stages` is used to define stages that can be used by jobs.
The specification of `stages` allows for having flexible multi stage pipelines.

The ordering of elements in `stages` defines the ordering of jobs' execution:

1. Jobs of the same stage are run in parallel.
1. Jobs of the next stage are run after the jobs from the previous stage
   complete successfully.

Let's consider the following example, which defines 3 stages:

```yaml
stages:
  - build
  - test
  - deploy
```

1. First, all jobs of `build` are executed in parallel.
1. If all jobs of `build` succeed, the `test` jobs are executed in parallel.
1. If all jobs of `test` succeed, the `deploy` jobs are executed in parallel.
1. If all jobs of `deploy` succeed, the commit is marked as `success`.
1. If any of the previous jobs fails, the commit is marked as `failed` and no
   jobs of further stage are executed.

There are also two edge cases worth mentioning:

1. If no `stages` are defined in `.gitlab-ci.yml`, then the `build`,
   `test` and `deploy` are allowed to be used as job's stage by default.
2. If a job doesn't specify a `stage`, the job is assigned the `test` stage.

### types

> Deprecated, and will be removed in 10.0. Use [stages](#stages) instead.

Alias for [stages](#stages).

### variables

> Introduced in GitLab Runner v0.5.0.

GitLab CI allows you to add variables to `.gitlab-ci.yml` that are set in the
job environment. The variables are stored in the Git repository and are meant
to store non-sensitive project configuration, for example:

```yaml
variables:
  DATABASE_URL: "postgres://postgres@postgres/my_database"
```

>**Note:**
Integers (as well as strings) are legal both for variable's name and value.
Floats are not legal and cannot be used.

These variables can be later used in all executed commands and scripts.
The YAML-defined variables are also set to all created service containers,
thus allowing to fine tune them. Variables can be also defined on a
[job level](#job-variables).

Except for the user defined variables, there are also the ones set up by the
Runner itself. One example would be `CI_COMMIT_REF_NAME` which has the value of
the branch or tag name for which project is built. Apart from the variables
you can set in `.gitlab-ci.yml`, there are also the so called secret variables
which can be set in GitLab's UI.

[Learn more about variables.][variables]

### cache

>
**Notes:**
- Introduced in GitLab Runner v0.7.0.
- Prior to GitLab 9.2, caches were restored after artifacts.
- From GitLab 9.2, caches are restored before artifacts.

`cache` is used to specify a list of files and directories which should be
cached between jobs. You can only use paths that are within the project
workspace.

**By default caching is enabled and shared between pipelines and jobs,
starting from GitLab 9.0**

If `cache` is defined outside the scope of jobs, it means it is set
globally and all jobs will use that definition.

Cache all files in `binaries` and `.config`:

```yaml
rspec:
  script: test
  cache:
    paths:
    - binaries/
    - .config
```

Cache all Git untracked files:

```yaml
rspec:
  script: test
  cache:
    untracked: true
```

Cache all Git untracked files and files in `binaries`:

```yaml
rspec:
  script: test
  cache:
    untracked: true
    paths:
    - binaries/
```

Locally defined cache overrides globally defined options. The following `rspec`
job will cache only `binaries/`:

```yaml
cache:
  paths:
  - my/files

rspec:
  script: test
  cache:
    key: rspec
    paths:
    - binaries/
```

Note that since cache is shared between jobs, if you're using different
paths for different jobs, you should also set a different **cache:key**
otherwise cache content can be overwritten.

The cache is provided on a best-effort basis, so don't expect that the cache
will be always present. For implementation details, please check GitLab Runner.

#### cache:key

> Introduced in GitLab Runner v1.0.0.

The `key` directive allows you to define the affinity of caching
between jobs, allowing to have a single cache for all jobs,
cache per-job, cache per-branch or any other way you deem proper.

This allows you to fine tune caching, allowing you to cache data between
different jobs or even different branches.

The `cache:key` variable can use any of the [predefined variables](../variables/README.md).

The default key is **default** across the project, therefore everything is
shared between each pipelines and jobs by default, starting from GitLab 9.0.

---

**Example configurations**

To enable per-job caching:

```yaml
cache:
  key: "$CI_JOB_NAME"
  untracked: true
```

To enable per-branch caching:

```yaml
cache:
  key: "$CI_COMMIT_REF_NAME"
  untracked: true
```

To enable per-job and per-branch caching:

```yaml
cache:
  key: "$CI_JOB_NAME/$CI_COMMIT_REF_NAME"
  untracked: true
```

To enable per-branch and per-stage caching:

```yaml
cache:
  key: "$CI_JOB_STAGE/$CI_COMMIT_REF_NAME"
  untracked: true
```

If you use **Windows Batch** to run your shell scripts you need to replace
`$` with `%`:

```yaml
cache:
  key: "%CI_JOB_STAGE%/%CI_COMMIT_REF_NAME%"
  untracked: true
```

If you use **Windows PowerShell** to run your shell scripts you need to replace
`$` with `$env:`:

```yaml
cache:
  key: "$env:CI_JOB_STAGE/$env:CI_COMMIT_REF_NAME"
  untracked: true
```

### cache:policy

> Introduced in GitLab 9.4.

The default behaviour of a caching job is to download the files at the start of
execution, and to re-upload them at the end. This allows any changes made by the
job to be persisted for future runs, and is known as the `pull-push` cache
policy.

If you know the job doesn't alter the cached files, you can skip the upload step
by setting `policy: pull` in the job specification. Typically, this would be
twinned with an ordinary cache job at an earlier stage to ensure the cache
is updated from time to time:

```yaml
stages:
  - setup
  - test

prepare:
  stage: setup
  cache:
    key: gems
    paths:
      - vendor/bundle
  script:
    - bundle install --deployment

rspec:
  stage: test
  cache:
    key: gems
    paths:
      - vendor/bundle
    policy: pull
  script:
    - bundle exec rspec ...
```

This helps to speed up job execution and reduce load on the cache server,
especially when you have a large number of cache-using jobs executing in
parallel.

Additionally, if you have a job that unconditionally recreates the cache without
reference to its previous contents, you can use `policy: push` in that job to
skip the download step.

## Jobs

`.gitlab-ci.yml` allows you to specify an unlimited number of jobs. Each job
must have a unique name, which is not one of the keywords mentioned above.
A job is defined by a list of parameters that define the job behavior.

```yaml
job_name:
  script:
    - rake spec
    - coverage
  stage: test
  only:
    - master
  except:
    - develop
  tags:
    - ruby
    - postgres
  allow_failure: true
```

| Keyword       | Required | Description |
|---------------|----------|-------------|
| script        | yes      | Defines a shell script which is executed by Runner |
| image         | no       | Use docker image, covered in [Using Docker Images](../docker/using_docker_images.md#define-image-and-services-from-gitlab-ciyml) |
| services      | no       | Use docker services, covered in [Using Docker Images](../docker/using_docker_images.md#define-image-and-services-from-gitlab-ciyml) |
| stage         | no       | Defines a job stage (default: `test`) |
| type          | no       | Alias for `stage` |
| variables     | no       | Define job variables on a job level |
| only          | no       | Defines a list of git refs for which job is created |
| except        | no       | Defines a list of git refs for which job is not created |
| tags          | no       | Defines a list of tags which are used to select Runner |
| allow_failure | no       | Allow job to fail. Failed job doesn't contribute to commit status |
| when          | no       | Define when to run job. Can be `on_success`, `on_failure`, `always` or `manual` |
| dependencies  | no       | Define other jobs that a job depends on so that you can pass artifacts between them|
| artifacts     | no       | Define list of [job artifacts](../../user/project/pipelines/job_artifacts.md) |
| cache         | no       | Define list of files that should be cached between subsequent runs |
| before_script | no       | Override a set of commands that are executed before job |
| after_script  | no       | Override a set of commands that are executed after job |
| environment   | no       | Defines a name of environment to which deployment is done by this job |
| coverage      | no       | Define code coverage settings for a given job |
| retry         | no       | Define how many times a job can be auto-retried in case of a failure |

### script

`script` is a shell script which is executed by the Runner. For example:

```yaml
job:
  script: "bundle exec rspec"
```

This parameter can also contain several commands using an array:

```yaml
job:
  script:
    - uname -a
    - bundle exec rspec
```

Sometimes, `script` commands will need to be wrapped in single or double quotes.
For example, commands that contain a colon (`:`) need to be wrapped in quotes so
that the YAML parser knows to interpret the whole thing as a string rather than
a "key: value" pair. Be careful when using special characters:
`:`, `{`, `}`, `[`, `]`, `,`, `&`, `*`, `#`, `?`, `|`, `-`, `<`, `>`, `=`, `!`, `%`, `@`, `` ` ``.

### stage

`stage` allows to group jobs into different stages. Jobs of the same `stage`
are executed in `parallel`. For more info about the use of `stage` please check
[stages](#stages).

### only and except

`only` and `except` are two parameters that set a refs policy to limit when
jobs are built:

1. `only` defines the names of branches and tags for which the job will run.
2. `except` defines the names of branches and tags for which the job will
    **not** run.

There are a few rules that apply to the usage of refs policy:

* `only` and `except` are inclusive. If both `only` and `except` are defined
   in a job specification, the ref is filtered by `only` and `except`.
* `only` and `except` allow the use of regular expressions.
* `only` and `except` allow to specify a repository path to filter jobs for
   forks.

In addition, `only` and `except` allow the use of special keywords:

| **Value** |  **Description**  |
| --------- |  ---------------- |
| `branches`  | When a branch is pushed.  |
| `tags`      | When a tag is pushed.  |
| `api`       | When pipeline has been triggered by a second pipelines API (not triggers API).  |
| `external`  | When using CI services other than GitLab. |
| `pipelines` | For multi-project triggers, created using the API with `CI_JOB_TOKEN`. |
| `pushes`    | Pipeline is triggered by a `git push` by the user. |
| `schedules` | For [scheduled pipelines][schedules]. |
| `triggers`  | For pipelines created using a trigger token. |
| `web`       | For pipelines created using **Run pipeline** button in GitLab UI (under your project's **Pipelines**). |

In the example below, `job` will run only for refs that start with `issue-`,
whereas all branches will be skipped:

```yaml
job:
  # use regexp
  only:
    - /^issue-.*$/
  # use special keyword
  except:
    - branches
```

In this example, `job` will run only for refs that are tagged, or if a build is
explicitly requested via an API trigger or a [Pipeline Schedule][schedules]:

```yaml
job:
  # use special keywords
  only:
    - tags
    - triggers
    - schedules
```

The repository path can be used to have jobs executed only for the parent
repository and not forks:

```yaml
job:
  only:
    - branches@gitlab-org/gitlab-ce
  except:
    - master@gitlab-org/gitlab-ce
```

The above example will run `job` for all branches on `gitlab-org/gitlab-ce`,
except master.

### Job variables

It is possible to define job variables using a `variables` keyword on a job
level. It works basically the same way as its [global-level equivalent](#variables),
but allows you to define job-specific variables.

When the `variables` keyword is used on a job level, it overrides the global YAML
job variables and predefined ones. To turn off global defined variables
in your job, define an empty hash:

```yaml
job_name:
  variables: {}
```

Job variables priority is defined in the [variables documentation][variables].

### tags

`tags` is used to select specific Runners from the list of all Runners that are
allowed to run this project.

During the registration of a Runner, you can specify the Runner's tags, for
example `ruby`, `postgres`, `development`.

`tags` allow you to run jobs with Runners that have the specified tags
assigned to them:

```yaml
job:
  tags:
    - ruby
    - postgres
```

The specification above, will make sure that `job` is built by a Runner that
has both `ruby` AND `postgres` tags defined.

### allow_failure

`allow_failure` is used when you want to allow a job to fail without impacting
the rest of the CI suite. Failed jobs don't contribute to the commit status.

When enabled and the job fails, the pipeline will be successful/green for all
intents and purposes, but a "CI build passed with warnings" message  will be
displayed on the merge request or commit or job page. This is to be used by
jobs that are allowed to fail, but where failure indicates some other (manual)
steps should be taken elsewhere.

In the example below, `job1` and `job2` will run in parallel, but if `job1`
fails, it will not stop the next stage from running, since it's marked with
`allow_failure: true`:

```yaml
job1:
  stage: test
  script:
  - execute_script_that_will_fail
  allow_failure: true

job2:
  stage: test
  script:
  - execute_script_that_will_succeed

job3:
  stage: deploy
  script:
  - deploy_to_staging
```

### when

`when` is used to implement jobs that are run in case of failure or despite the
failure.

`when` can be set to one of the following values:

1. `on_success` - execute job only when all jobs from prior stages
    succeed. This is the default.
1. `on_failure` - execute job only when at least one job from prior stages
    fails.
1. `always` - execute job regardless of the status of jobs from prior stages.
1. `manual` - execute job manually (added in GitLab 8.10). Read about
    [manual actions](#manual-actions) below.

For example:

```yaml
stages:
- build
- cleanup_build
- test
- deploy
- cleanup

build_job:
  stage: build
  script:
  - make build

cleanup_build_job:
  stage: cleanup_build
  script:
  - cleanup build when failed
  when: on_failure

test_job:
  stage: test
  script:
  - make test

deploy_job:
  stage: deploy
  script:
  - make deploy
  when: manual

cleanup_job:
  stage: cleanup
  script:
  - cleanup after jobs
  when: always
```

The above script will:

1. Execute `cleanup_build_job` only when `build_job` fails.
2. Always execute `cleanup_job` as the last step in pipeline regardless of
   success or failure.
3. Allow you to manually execute `deploy_job` from GitLab's UI.

#### Manual actions

> Introduced in GitLab 8.10.
> Blocking manual actions were introduced in GitLab 9.0
> Protected actions were introduced in GitLab 9.2

Manual actions are a special type of job that are not executed automatically;
they need to be explicitly started by a user. Manual actions can be started
from pipeline, build, environment, and deployment views.

An example usage of manual actions is deployment to production.

Read more at the [environments documentation][env-manual].

Manual actions can be either optional or blocking. Blocking manual action will
block execution of the pipeline at stage this action is defined in. It is
possible to resume execution of the pipeline when someone executes a blocking
manual actions by clicking a _play_ button.

When pipeline is blocked it will not be merged if Merge When Pipeline Succeeds
is set. Blocked pipelines also do have a special status, called _manual_.

Manual actions are non-blocking by default. If you want to make manual action
blocking, it is necessary to add `allow_failure: false` to the job's definition
in `.gitlab-ci.yml`.

Optional manual actions have `allow_failure: true` set by default.

**Statuses of optional actions do not contribute to overall pipeline status.**

**Manual actions are considered to be write actions, so permissions for
protected branches are used when user wants to trigger an action. In other
words, in order to trigger a manual action assigned to a branch that the
pipeline is running for, user needs to have ability to merge to this branch.**

### environment

>
**Notes:**
- Introduced in GitLab 8.9.
- You can read more about environments and find more examples in the
  [documentation about environments][environment].

`environment` is used to define that a job deploys to a specific environment.
If `environment` is specified and no environment under that name exists, a new
one will be created automatically.

In its simplest form, the `environment` keyword can be defined like:

```yaml
deploy to production:
  stage: deploy
  script: git push production HEAD:master
  environment:
    name: production
```

In the above example, the `deploy to production` job will be marked as doing a
deployment to the `production` environment.

#### environment:name

>
**Notes:**
- Introduced in GitLab 8.11.
- Before GitLab 8.11, the name of an environment could be defined as a string like
  `environment: production`. The recommended way now is to define it under the
  `name` keyword.

The `environment` name can contain:

- letters
- digits
- spaces
- `-`
- `_`
- `/`
- `$`
- `{`
- `}`

Common names are `qa`, `staging`, and `production`, but you can use whatever
name works with your workflow.

Instead of defining the name of the environment right after the `environment`
keyword, it is also possible to define it as a separate value. For that, use
the `name` keyword under `environment`:

```yaml
deploy to production:
  stage: deploy
  script: git push production HEAD:master
  environment:
    name: production
```

#### environment:url

>
**Notes:**
- Introduced in GitLab 8.11.
- Before GitLab 8.11, the URL could be added only in GitLab's UI. The
  recommended way now is to define it in `.gitlab-ci.yml`.

This is an optional value that when set, it exposes buttons in various places
in GitLab which when clicked take you to the defined URL.

In the example below, if the job finishes successfully, it will create buttons
in the merge requests and in the environments/deployments pages which will point
to `https://prod.example.com`.

```yaml
deploy to production:
  stage: deploy
  script: git push production HEAD:master
  environment:
    name: production
    url: https://prod.example.com
```

#### environment:on_stop

>
**Notes:**
- [Introduced][ce-6669] in GitLab 8.13.
- Starting with GitLab 8.14, when you have an environment that has a stop action
  defined, GitLab will automatically trigger a stop action when the associated
  branch is deleted.

Closing (stoping) environments can be achieved with the `on_stop` keyword defined under
`environment`. It declares a different job that runs in order to close
the environment.

Read the `environment:action` section for an example.

#### environment:action

> [Introduced][ce-6669] in GitLab 8.13.

The `action` keyword is to be used in conjunction with `on_stop` and is defined
in the job that is called to close the environment.

Take for instance:

```yaml
review_app:
  stage: deploy
  script: make deploy-app
  environment:
    name: review
    on_stop: stop_review_app

stop_review_app:
  stage: deploy
  script: make delete-app
  when: manual
  environment:
    name: review
    action: stop
```

In the above example we set up the `review_app` job to deploy to the `review`
environment, and we also defined a new `stop_review_app` job under `on_stop`.
Once the `review_app` job is successfully finished, it will trigger the
`stop_review_app` job based on what is defined under `when`. In this case we
set it up to `manual` so it will need a [manual action](#manual-actions) via
GitLab's web interface in order to run.

The `stop_review_app` job is **required** to have the following keywords defined:

- `when` - [reference](#when)
- `environment:name`
- `environment:action`
- `stage` should be the same as the `review_app` in order for the environment
  to stop automatically when the branch is deleted

#### dynamic environments

>
**Notes:**
- [Introduced][ce-6323] in GitLab 8.12 and GitLab Runner 1.6.
- The `$CI_ENVIRONMENT_SLUG` was [introduced][ce-7983] in GitLab 8.15.

`environment` can also represent a configuration hash with `name` and `url`.
These parameters can use any of the defined [CI variables](#variables)
(including predefined, secure variables and `.gitlab-ci.yml` variables).

For example:

```yaml
deploy as review app:
  stage: deploy
  script: make deploy
  environment:
    name: review/$CI_COMMIT_REF_NAME
    url: https://$CI_ENVIRONMENT_SLUG.example.com/
```

The `deploy as review app` job will be marked as deployment to dynamically
create the `review/$CI_COMMIT_REF_NAME` environment, where `$CI_COMMIT_REF_NAME`
is an [environment variable][variables] set by the Runner. The
`$CI_ENVIRONMENT_SLUG` variable is based on the environment name, but suitable
for inclusion in URLs. In this case, if the `deploy as review app` job was run
in a branch named `pow`, this environment would be accessible with an URL like
`https://review-pow.example.com/`.

This of course implies that the underlying server which hosts the application
is properly configured.

The common use case is to create dynamic environments for branches and use them
as Review Apps. You can see a simple example using Review Apps at
<https://gitlab.com/gitlab-examples/review-apps-nginx/>.

### artifacts

>
**Notes:**
- Introduced in GitLab Runner v0.7.0 for non-Windows platforms.
- Windows support was added in GitLab Runner v.1.0.0.
- Prior to GitLab 9.2, caches were restored after artifacts.
- From GitLab 9.2, caches are restored before artifacts.
- Currently not all executors are supported.
- Job artifacts are only collected for successful jobs by default.

`artifacts` is used to specify a list of files and directories which should be
attached to the job after success. You can only use paths that are within the
project workspace. To pass artifacts between different jobs, see [dependencies](#dependencies).
Below are some examples.

Send all files in `binaries` and `.config`:

```yaml
artifacts:
  paths:
  - binaries/
  - .config
```

Send all Git untracked files:

```yaml
artifacts:
  untracked: true
```

Send all Git untracked files and files in `binaries`:

```yaml
artifacts:
  untracked: true
  paths:
  - binaries/
```

To disable artifact passing, define the job with empty [dependencies](#dependencies):

```yaml
job:
  stage: build
  script: make build
  dependencies: []
```

You may want to create artifacts only for tagged releases to avoid filling the
build server storage with temporary build artifacts.

Create artifacts only for tags (`default-job` will not create artifacts):

```yaml
default-job:
  script:
    - mvn test -U
  except:
    - tags

release-job:
  script:
    - mvn package -U
  artifacts:
    paths:
    - target/*.war
  only:
    - tags
```

The artifacts will be sent to GitLab after the job finishes successfully and will
be available for download in the GitLab UI.

#### artifacts:name

> Introduced in GitLab 8.6 and GitLab Runner v1.1.0.

The `name` directive allows you to define the name of the created artifacts
archive. That way, you can have a unique name for every archive which could be
useful when you'd like to download the archive from GitLab. The `artifacts:name`
variable can make use of any of the [predefined variables](../variables/README.md).
The default name is `artifacts`, which becomes `artifacts.zip` when downloaded.

---

**Example configurations**

To create an archive with a name of the current job:

```yaml
job:
  artifacts:
    name: "$CI_JOB_NAME"
```

To create an archive with a name of the current branch or tag including only
the files that are untracked by Git:

```yaml
job:
   artifacts:
     name: "$CI_COMMIT_REF_NAME"
     untracked: true
```

To create an archive with a name of the current job and the current branch or
tag including only the files that are untracked by Git:

```yaml
job:
  artifacts:
    name: "${CI_JOB_NAME}_${CI_COMMIT_REF_NAME}"
    untracked: true
```

To create an archive with a name of the current [stage](#stages) and branch name:

```yaml
job:
  artifacts:
    name: "${CI_JOB_STAGE}_${CI_COMMIT_REF_NAME}"
    untracked: true
```

---

If you use **Windows Batch** to run your shell scripts you need to replace
`$` with `%`:

```yaml
job:
  artifacts:
    name: "%CI_JOB_STAGE%_%CI_COMMIT_REF_NAME%"
    untracked: true
```

If you use **Windows PowerShell** to run your shell scripts you need to replace
`$` with `$env:`:

```yaml
job:
  artifacts:
    name: "$env:CI_JOB_STAGE_$env:CI_COMMIT_REF_NAME"
    untracked: true
```

#### artifacts:when

> Introduced in GitLab 8.9 and GitLab Runner v1.3.0.

`artifacts:when` is used to upload artifacts on job failure or despite the
failure.

`artifacts:when` can be set to one of the following values:

1. `on_success` - upload artifacts only when the job succeeds. This is the default.
1. `on_failure` - upload artifacts only when the job fails.
1. `always` - upload artifacts regardless of the job status.

---

**Example configurations**

To upload artifacts only when job fails.

```yaml
job:
  artifacts:
    when: on_failure
```

#### artifacts:expire_in

> Introduced in GitLab 8.9 and GitLab Runner v1.3.0.

`artifacts:expire_in` is used to delete uploaded artifacts after the specified
time. By default, artifacts are stored on GitLab forever. `expire_in` allows you
to specify how long artifacts should live before they expire, counting from the
time they are uploaded and stored on GitLab.

You can use the **Keep** button on the job page to override expiration and
keep artifacts forever.

After expiry, artifacts are actually deleted hourly by default (via a cron job),
but they are not accessible after expiry.

The value of `expire_in` is an elapsed time. Examples of parseable values:

- '3 mins 4 sec'
- '2 hrs 20 min'
- '2h20min'
- '6 mos 1 day'
- '47 yrs 6 mos and 4d'
- '3 weeks and 2 days'

---

**Example configurations**

To expire artifacts 1 week after being uploaded:

```yaml
job:
  artifacts:
    expire_in: 1 week
```

### dependencies

> Introduced in GitLab 8.6 and GitLab Runner v1.1.1.

This feature should be used in conjunction with [`artifacts`](#artifacts) and
allows you to define the artifacts to pass between different jobs.

Note that `artifacts` from all previous [stages](#stages) are passed by default.

To use this feature, define `dependencies` in context of the job and pass
a list of all previous jobs from which the artifacts should be downloaded.
You can only define jobs from stages that are executed before the current one.
An error will be shown if you define jobs from the current stage or next ones.
Defining an empty array will skip downloading any artifacts for that job.

---

In the following example, we define two jobs with artifacts, `build:osx` and
`build:linux`. When the `test:osx` is executed, the artifacts from `build:osx`
will be downloaded and extracted in the context of the build. The same happens
for `test:linux` and artifacts from `build:linux`.

The job `deploy` will download artifacts from all previous jobs because of
the [stage](#stages) precedence:

```yaml
build:osx:
  stage: build
  script: make build:osx
  artifacts:
    paths:
    - binaries/

build:linux:
  stage: build
  script: make build:linux
  artifacts:
    paths:
    - binaries/

test:osx:
  stage: test
  script: make test:osx
  dependencies:
  - build:osx

test:linux:
  stage: test
  script: make test:linux
  dependencies:
  - build:linux

deploy:
  stage: deploy
  script: make deploy
```

### before_script and after_script

It's possible to overwrite the globally defined `before_script` and `after_script`:

```yaml
before_script:
- global before script

job:
  before_script:
  - execute this instead of global before script
  script:
  - my command
  after_script:
  - execute this after my script
```

### coverage

**Notes:**
- [Introduced][ce-7447] in GitLab 8.17.

`coverage` allows you to configure how code coverage will be extracted from the
job output.

Regular expressions are the only valid kind of value expected here. So, using
surrounding `/` is mandatory in order to consistently and explicitly represent
a regular expression string. You must escape special characters if you want to
match them literally.

A simple example:

```yaml
job1:
  script: rspec
  coverage: '/Code coverage: \d+\.\d+/'
```

### retry

**Notes:**
- [Introduced][ce-3442] in GitLab 9.5.

`retry` allows you to configure how many times a job is going to be retried in
case of a failure.

When a job fails, and has `retry` configured it is going to be processed again
up to the amount of times specified by the `retry` keyword.

If `retry` is set to 2, and a job succeeds in a second run (first retry), it won't be retried
again. `retry` value has to be a positive integer, equal or larger than 0, but
lower or equal to 2 (two retries maximum, three runs in total).

A simple example:

```yaml
test:
  script: rspec
  retry: 2
```

## Git Strategy

> Introduced in GitLab 8.9 as an experimental feature.  May change or be removed
  completely in future releases. `GIT_STRATEGY=none` requires GitLab Runner
  v1.7+.

You can set the `GIT_STRATEGY` used for getting recent application code, either
in the global [`variables`](#variables) section or the [`variables`](#job-variables)
section for individual jobs. If left unspecified, the default from project
settings will be used.

There are three possible values: `clone`, `fetch`, and `none`.

`clone` is the slowest option. It clones the repository from scratch for every
job, ensuring that the project workspace is always pristine.

```yaml
variables:
  GIT_STRATEGY: clone
```

`fetch` is faster as it re-uses the project workspace (falling back to `clone`
if it doesn't exist). `git clean` is used to undo any changes made by the last
job, and `git fetch` is used to retrieve commits made since the last job ran.

```yaml
variables:
  GIT_STRATEGY: fetch
```

`none` also re-uses the project workspace, but skips all Git operations
(including GitLab Runner's pre-clone script, if present). It is mostly useful
for jobs that operate exclusively on artifacts (e.g., `deploy`). Git repository
data may be present, but it is certain to be out of date, so you should only
rely on files brought into the project workspace from cache or artifacts.

```yaml
variables:
  GIT_STRATEGY: none
```

## Git Checkout

> Introduced in GitLab Runner 9.3

The `GIT_CHECKOUT` variable can be used when the `GIT_STRATEGY` is set to either
`clone` or `fetch` to specify whether a `git checkout` should be run. If not
specified, it defaults to true. Like `GIT_STRATEGY`, it can be set in either the
global [`variables`](#variables) section or the [`variables`](#job-variables)
section for individual jobs.

If set to `false`, the Runner will:

- when doing `fetch` - update the repository and leave working copy on
  the current revision,
- when doing `clone` - clone the repository and leave working copy on the
  default branch.

Having this setting set to `true` will mean that for both `clone` and `fetch`
strategies the Runner will checkout the working copy to a revision related
to the CI pipeline:

```yaml
variables:
  GIT_STRATEGY: clone
  GIT_CHECKOUT: false
script:
  - git checkout master
  - git merge $CI_BUILD_REF_NAME
```

## Git Submodule Strategy

> Requires GitLab Runner v1.10+.

The `GIT_SUBMODULE_STRATEGY` variable is used to control if / how Git
submodules are included when fetching the code before a build. Like
`GIT_STRATEGY`, it can be set in either the global [`variables`](#variables)
section or the [`variables`](#job-variables) section for individual jobs.

There are three possible values: `none`, `normal`, and `recursive`:

- `none` means that submodules will not be included when fetching the project
  code. This is the default, which matches the pre-v1.10 behavior.

- `normal` means that only the top-level submodules will be included. It is
  equivalent to:

    ```
    git submodule sync
    git submodule update --init
    ```

- `recursive` means that all submodules (including submodules of submodules)
  will be included. It is equivalent to:

    ```
    git submodule sync --recursive
    git submodule update --init --recursive
    ```

Note that for this feature to work correctly, the submodules must be configured
(in `.gitmodules`) with either:

- the HTTP(S) URL of a publicly-accessible repository, or
- a relative path to another repository on the same GitLab server. See the
  [Git submodules](../git_submodules.md) documentation.


## Job stages attempts

> Introduced in GitLab, it requires GitLab Runner v1.9+.

You can set the number for attempts the running job will try to execute each
of the following stages:

| Variable                        | Description |
|-------------------------------- |-------------|
| **GET_SOURCES_ATTEMPTS**        | Number of attempts to fetch sources running a job |
| **ARTIFACT_DOWNLOAD_ATTEMPTS**  | Number of attempts to download artifacts running a job |
| **RESTORE_CACHE_ATTEMPTS**      | Number of attempts to restore the cache running a job |

The default is one single attempt.

Example:

```yaml
variables:
  GET_SOURCES_ATTEMPTS: 3
```

You can set them in the global [`variables`](#variables) section or the
[`variables`](#job-variables) section for individual jobs.

## Shallow cloning

> Introduced in GitLab 8.9 as an experimental feature. May change in future
releases or be removed completely.

You can specify the depth of fetching and cloning using `GIT_DEPTH`. This allows
shallow cloning of the repository which can significantly speed up cloning for
repositories with a large number of commits or old, large binaries. The value is
passed to `git fetch` and `git clone`.

>**Note:**
If you use a depth of 1 and have a queue of jobs or retry
jobs, jobs may fail.

Since Git fetching and cloning is based on a ref, such as a branch name, Runners
can't clone a specific commit SHA. If there are multiple jobs in the queue, or
you are retrying an old job, the commit to be tested needs to be within the
Git history that is cloned. Setting too small a value for `GIT_DEPTH` can make
it impossible to run these old commits. You will see `unresolved reference` in
job logs. You should then reconsider changing `GIT_DEPTH` to a higher value.

Jobs that rely on `git describe` may not work correctly when `GIT_DEPTH` is
set since only part of the Git history is present.

To fetch or clone only the last 3 commits:

```yaml
variables:
  GIT_DEPTH: "3"
```

## Hidden keys

> Introduced in GitLab 8.6 and GitLab Runner v1.1.1.

Keys that start with a dot (`.`) will be not processed by GitLab CI. You can
use this feature to ignore jobs, or use the
[special YAML features](#special-yaml-features) and transform the hidden keys
into templates.

In the following example, `.key_name` will be ignored:

```yaml
.key_name:
  script:
    - rake spec
```

Hidden keys can be hashes like normal CI jobs, but you are also allowed to use
different types of structures to leverage special YAML features.

## Special YAML features

It's possible to use special YAML features like anchors (`&`), aliases (`*`)
and map merging (`<<`), which will allow you to greatly reduce the complexity
of `.gitlab-ci.yml`.

Read more about the various [YAML features](https://learnxinyminutes.com/docs/yaml/).

### Anchors

> Introduced in GitLab 8.6 and GitLab Runner v1.1.1.

YAML has a handy feature called 'anchors', which lets you easily duplicate
content across your document. Anchors can be used to duplicate/inherit
properties, and is a perfect example to be used with [hidden keys](#hidden-keys)
to provide templates for your jobs.

The following example uses anchors and map merging. It will create two jobs,
`test1` and `test2`, that will inherit the parameters of `.job_template`, each
having their own custom `script` defined:

```yaml
.job_template: &job_definition  # Hidden key that defines an anchor named 'job_definition'
  image: ruby:2.1
  services:
    - postgres
    - redis

test1:
  <<: *job_definition           # Merge the contents of the 'job_definition' alias
  script:
    - test1 project

test2:
  <<: *job_definition           # Merge the contents of the 'job_definition' alias
  script:
    - test2 project
```

`&` sets up the name of the anchor (`job_definition`), `<<` means "merge the
given hash into the current one", and `*` includes the named anchor
(`job_definition` again). The expanded version looks like this:

```yaml
.job_template:
  image: ruby:2.1
  services:
    - postgres
    - redis

test1:
  image: ruby:2.1
  services:
    - postgres
    - redis
  script:
    - test1 project

test2:
  image: ruby:2.1
  services:
    - postgres
    - redis
  script:
    - test2 project
```

Let's see another one example. This time we will use anchors to define two sets
of services. This will create two jobs, `test:postgres` and `test:mysql`, that
will share the `script` directive defined in `.job_template`, and the `services`
directive defined in `.postgres_services` and `.mysql_services` respectively:

```yaml
.job_template: &job_definition
  script:
    - test project

.postgres_services:
  services: &postgres_definition
    - postgres
    - ruby

.mysql_services:
  services: &mysql_definition
    - mysql
    - ruby

test:postgres:
  <<: *job_definition
  services: *postgres_definition

test:mysql:
  <<: *job_definition
  services: *mysql_definition
```

The expanded version looks like this:

```yaml
.job_template:
  script:
    - test project

.postgres_services:
  services:
    - postgres
    - ruby

.mysql_services:
  services:
    - mysql
    - ruby

test:postgres:
  script:
    - test project
  services:
    - postgres
    - ruby

test:mysql:
  script:
    - test project
  services:
    - mysql
    - ruby
```

You can see that the hidden keys are conveniently used as templates.

## Triggers

Triggers can be used to force a rebuild of a specific branch, tag or commit,
with an API call.

[Read more in the triggers documentation.](../triggers/README.md)

### pages

`pages` is a special job that is used to upload static content to GitLab that
can be used to serve your website. It has a special syntax, so the two
requirements below must be met:

1. Any static content must be placed under a `public/` directory
1. `artifacts` with a path to the `public/` directory must be defined

The example below simply moves all files from the root of the project to the
`public/` directory. The `.public` workaround is so `cp` doesn't also copy
`public/` to itself in an infinite loop:

```
pages:
  stage: deploy
  script:
  - mkdir .public
  - cp -r * .public
  - mv .public public
  artifacts:
    paths:
    - public
  only:
  - master
```

Read more on [GitLab Pages user documentation](../../user/project/pages/index.md).

## Validate the .gitlab-ci.yml

Each instance of GitLab CI has an embedded debug tool called Lint.
You can find the link under `/ci/lint` of your gitlab instance.

## Skipping jobs

If your commit message contains `[ci skip]` or `[skip ci]`, using any
capitalization, the commit will be created but the jobs will be skipped.

## Examples

Visit the [examples README][examples] to see a list of examples using GitLab
CI with various languages.

[env-manual]: ../environments.md#manually-deploying-to-environments
[examples]: ../examples/README.md
[ce-6323]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/6323
[environment]: ../environments.md
[ce-6669]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/6669
[variables]: ../variables/README.md
[ce-7983]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/7983
[ce-7447]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/7447
[ce-3442]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/3442
[schedules]: ../../user/project/pipelines/schedules.md
