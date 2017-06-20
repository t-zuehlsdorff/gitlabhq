# Using Docker Images

GitLab CI in conjunction with [GitLab Runner](../runners/README.md) can use
[Docker Engine](https://www.docker.com/) to test and build any application.

Docker is an open-source project that allows you to use predefined images to
run applications in independent "containers" that are run within a single Linux
instance. [Docker Hub][hub] has a rich database of pre-built images that can be
used to test and build your applications.

Docker, when used with GitLab CI, runs each job in a separate and isolated
container using the predefined image that is set up in
[`.gitlab-ci.yml`](../yaml/README.md).

This makes it easier to have a simple and reproducible build environment that
can also run on your workstation. The added benefit is that you can test all
the commands that we will explore later from your shell, rather than having to
test them on a dedicated CI server.

## Register docker runner

To use GitLab Runner with docker you need to register a new runner to use the
`docker` executor:

```bash
gitlab-ci-multi-runner register \
  --url "https://gitlab.com/" \
  --registration-token "PROJECT_REGISTRATION_TOKEN" \
  --description "docker-ruby-2.1" \
  --executor "docker" \
  --docker-image ruby:2.1 \
  --docker-postgres latest \
  --docker-mysql latest
```

The registered runner will use the `ruby:2.1` docker image and will run two
services, `postgres:latest` and `mysql:latest`, both of which will be
accessible during the build process.

## What is an image

The `image` keyword is the name of the docker image the docker executor
will run to perform the CI tasks.  

By default the executor will only pull images from [Docker Hub][hub],
but this can be configured in the `gitlab-runner/config.toml` by setting
the [docker pull policy][] to allow using local images.

For more information about images and Docker Hub please read
the [Docker Fundamentals][] documentation.

## What is a service

The `services` keyword defines just another docker image that is run during
your job and is linked to the docker image that the `image` keyword defines.
This allows you to access the service image during build time.

The service image can run any application, but the most common use case is to
run a database container, eg. `mysql`. It's easier and faster to use an
existing image and run it as an additional container than install `mysql` every
time the project is built.

You can see some widely used services examples in the relevant documentation of
[CI services examples](../services/README.md).

### How services are linked to the job

To better understand how the container linking works, read
[Linking containers together][linking-containers].

To summarize, if you add `mysql` as service to your application, the image will
then be used to create a container that is linked to the job container.

The service container for MySQL will be accessible under the hostname `mysql`.
So, in order to access your database service you have to connect to the host
named `mysql` instead of a socket or `localhost`.

## Overwrite image and services

See [How to use other images as services](#how-to-use-other-images-as-services).

## How to use other images as services

You are not limited to have only database services. You can add as many
services you need to `.gitlab-ci.yml` or manually modify `config.toml`.
Any image found at [Docker Hub][hub] can be used as a service.

## Define image and services from `.gitlab-ci.yml`

You can simply define an image that will be used for all jobs and a list of
services that you want to use during build time.

```yaml
image: ruby:2.2

services:
  - postgres:9.3

before_script:
  - bundle install

test:
  script:
  - bundle exec rake spec
```

It is also possible to define different images and services per job:

```yaml
before_script:
  - bundle install

test:2.1:
  image: ruby:2.1
  services:
  - postgres:9.3
  script:
  - bundle exec rake spec

test:2.2:
  image: ruby:2.2
  services:
  - postgres:9.4
  script:
  - bundle exec rake spec
```

## Define image and services in `config.toml`

Look for the `[runners.docker]` section:

```
[runners.docker]
  image = "ruby:2.1"
  services = ["mysql:latest", "postgres:latest"]
```

The image and services defined this way will be added to all job run by
that runner.

## Define an image from a private Docker registry

> **Notes:**
- This feature requires GitLab Runner **1.8** or higher
- For GitLab Runner versions **>= 0.6, <1.8** there was a partial
  support for using private registries, which required manual configuration
  of credentials on runner's host. We recommend to upgrade your Runner to
  at least version **1.8** if you want to use private registries.
- If the repository is private you need to authenticate your GitLab Runner in the
  registry. Learn more about how [GitLab Runner works in this case][runner-priv-reg].

As an example, let's assume that you want to use the `registry.example.com/private/image:latest`
image which is private and requires you to login into a private container registry.
To configure access for `registry.example.com`, follow these steps:

1. Do a `docker login` on your computer:

     ```bash
     docker login registry.example.com --username my_username --password my_password
     ```

1. Copy the content of `~/.docker/config.json`
1. Create a [secret variable] `DOCKER_AUTH_CONFIG` with the content of the
   Docker configuration file as the value:

     ```json
     {
         "auths": {
             "registry.example.com": {
                 "auth": "bXlfdXNlcm5hbWU6bXlfcGFzc3dvcmQ="
             }
         }
     }
     ```

1. Do a `docker logout` on your computer if you don't need access to the
   registry from it:

     ```bash
     docker logout registry.example.com
     ```

1. You can now use any private image from `registry.example.com` defined in
   `image` and/or `services` in your [`.gitlab-ci.yml` file][yaml-priv-reg]:

      ```yaml
      image: my.registry.tld:5000/namespace/image:tag
      ```

      In the example above, GitLab Runner will look at `my.registry.tld:5000` for the
      image `namespace/image:tag`.

You can add configuration for as many registries as you want, adding more
registries to the `"auths"` hash as described above.

## Accessing the services

Let's say that you need a Wordpress instance to test some API integration with
your application.

You can then use for example the [tutum/wordpress][] image in your
`.gitlab-ci.yml`:

```yaml
services:
- tutum/wordpress:latest
```

When the job is run, `tutum/wordpress` will be started and you will have
access to it from your build container under the hostnames `tutum-wordpress`
(requires GitLab Runner v1.1.0 or newer) and `tutum__wordpress`.

When using a private registry, the image name also includes a hostname and port
of the registry. 

```yaml
services:
- docker.example.com:5000/wordpress:latest
```

The service hostname will also include the registry hostname. Service will be
available under hostnames `docker.example.com-wordpress` (requires GitLab Runner v1.1.0 or newer)
and `docker.example.com__wordpress`.

*Note: hostname with underscores is not RFC valid and may cause problems in 3rd party applications.*

The alias hostnames for the service are made from the image name following these
rules:

1. Everything after `:` is stripped
2. Slash (`/`) is replaced with double underscores (`__`) - primary alias
3. Slash (`/`) is replaced with dash (`-`) - secondary alias, requires GitLab Runner v1.1.0 or newer

## Configuring services

Many services accept environment variables which allow you to easily change
database names or set account names depending on the environment.

GitLab Runner 0.5.0 and up passes all YAML-defined variables to the created
service containers.

For all possible configuration variables check the documentation of each image
provided in their corresponding Docker hub page.

*Note: All variables will be passed to all services containers. It's not
designed to distinguish which variable should go where.*

### PostgreSQL service example

See the specific documentation for
[using PostgreSQL as a service](../services/postgres.md).

### MySQL service example

See the specific documentation for
[using MySQL as a service](../services/mysql.md).

## How Docker integration works

Below is a high level overview of the steps performed by docker during job
time.

1. Create any service container: `mysql`, `postgresql`, `mongodb`, `redis`.
1. Create cache container to store all volumes as defined in `config.toml` and
   `Dockerfile` of build image (`ruby:2.1` as in above example).
1. Create build container and link any service container to build container.
1. Start build container and send job script to the container.
1. Run job script.
1. Checkout code in: `/builds/group-name/project-name/`.
1. Run any step defined in `.gitlab-ci.yml`.
1. Check exit status of build script.
1. Remove build container and all created service containers.

## How to debug a job locally

*Note: The following commands are run without root privileges. You should be
able to run docker with your regular user account.*

First start with creating a file named `build_script`:

```bash
cat <<EOF > build_script
git clone https://gitlab.com/gitlab-org/gitlab-ci-multi-runner.git /builds/gitlab-org/gitlab-ci-multi-runner
cd /builds/gitlab-org/gitlab-ci-multi-runner
make
EOF
```

Here we use as an example the GitLab Runner repository which contains a
Makefile, so running `make` will execute the commands defined in the Makefile.
Your mileage may vary, so instead of `make` you could run the command which
is specific to your project.

Then create some service containers:

```
docker run -d --name service-mysql mysql:latest
docker run -d --name service-postgres postgres:latest
```

This will create two service containers, named `service-mysql` and
`service-postgres` which use the latest MySQL and PostgreSQL images
respectively. They will both run in the background (`-d`).

Finally, create a build container by executing the `build_script` file we
created earlier:

```
docker run --name build -i --link=service-mysql:mysql --link=service-postgres:postgres ruby:2.1 /bin/bash < build_script
```

The above command will create a container named `build` that is spawned from
the `ruby:2.1` image and has two services linked to it. The `build_script` is
piped using STDIN to the bash interpreter which in turn executes the
`build_script` in the `build` container.

When you finish testing and no longer need the containers, you can remove them
with:

```
docker rm -f -v build service-mysql service-postgres
```

This will forcefully (`-f`) remove the `build` container, the two service
containers as well as all volumes (`-v`) that were created with the container
creation.

[Docker Fundamentals]: https://docs.docker.com/engine/understanding-docker/
[docker pull policy]: https://docs.gitlab.com/runner/executors/docker.html#how-pull-policies-work
[hub]: https://hub.docker.com/
[linking-containers]: https://docs.docker.com/engine/userguide/networking/default_network/dockerlinks/
[tutum/wordpress]: https://hub.docker.com/r/tutum/wordpress/
[postgres-hub]: https://hub.docker.com/r/_/postgres/
[mysql-hub]: https://hub.docker.com/r/_/mysql/
[runner-priv-reg]: http://docs.gitlab.com/runner/configuration/advanced-configuration.html#using-a-private-container-registry
[secret variable]: ../variables/README.md#secret-variables
