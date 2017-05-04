# Installation at FreeBSD

## Important Notes

This guide is long because it covers many cases and includes all commands you need.

This installation guide was created for and tested on **FreeBSD** operating systems. Please read [doc/install/requirements.md](./requirements.md) for hardware and operating system requirements.

This is the official installation guide to set up a production server. To set up a **development installation** or for many other installation options please see [the installation section of the readme](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/README.md#installation).

The following steps have been known to work. Please **use caution when you deviate** from this guide. Make sure you don't violate any assumptions GitLab makes about its environment. For example many people run into permission problems because they changed the location of directories or run services as the wrong user.

If not mentioned otherwise, please perform the commands as **root**!

If you find a bug/error in this guide please **submit a merge request**
following the
[contributing guide](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/CONTRIBUTING.md).

## Overview

The GitLab installation consists of setting up the following components:

1. Package or Port
1. Database
1. Redis
1. GitLab
1. Nginx

## 1. Package or Port

There are two methods to install Gitlab: as binary package (fast, easy) or compile it from the source (relatively easy).

It is recommended to use binary package installation. All dependencies will be installed automatically:

    pkg install www/gitlab
    sysrc gitlab_enable=YES

In order to get the latest version and timely security patches it may be necessary to switch to 'latest' instead of 'quarterly' packages.

    mkdir -p /usr/local/etc/pkg/repos
    vi /usr/local/etc/pkg/repos/FreeBSD.conf

    # add the following to FreeBSD.conf:

    FreeBSD: {
      url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest"
    }

    pkg upgrade

You are free to build it from source. Please checkout the latest ports-tree and follow these steps:

    cd /usr/ports/www/gitlab
    make install
    sysrc gitlab_enable=YES

## 2. Database

We recommend using a PostgreSQL database. For MySQL check [MySQL setup guide](database_mysql.md). *Note*: because we need to make use of extensions you need at least pgsql 9.1.
The current default version of PostgreSQL in the Portstree is 9.3 and is therefore used. *Note*: we do not cope how to install PostgreSQL properly.
*Attention*: since PostgreSQL 9.6 the "pgsql" user is renamed to "postgres". PostgreSQL 9.6 user need to change the name accordingly.

    # Install the database packages
    # If you want newer versions change them appropriately to: postgresql94-server, postgresql94-server, etc.
    pkg install postgresql93-server postgresql93-contrib

    # NOTE: When running in a jail, you must add the following line to file "/etc/sysctl.conf" of the *host*:
    security.jail.sysvipc_allowed=1
    # If the jail is already running, execute the following on the jail's host:
    jail -m jid=<jail_id> allow.sysvipc=1
    # Likewise, if running in a FreeNAS jail, open Advanced Configuration for the specific
    # Gitlab jail and append the following to any existing "Sysctls":
    allow.sysvipc=1

    # allow postgresql to start; also init and start it
    sysrc postgresql_enable=YES
    service postgresql initdb
    service postgresql start

    # create user git
    # ATTENTION: for first installation superuser rights are needed; after installation this should be removed!
    psql -d template1 -U pgsql -c "CREATE USER git CREATEDB SUPERUSER;"

    # Create the GitLab production database & grant all privileges on database
    psql -d template1 -U pgsql -c "CREATE DATABASE gitlabhq_production OWNER git;"

    # Try connecting to the new database with the new user
    psql -U git -d gitlabhq_production
      
    # Check if the `pg_trgm` extension is enabled by executing this SQL-statement:
    SELECT true AS enabled
    FROM pg_available_extensions
    WHERE name = 'pg_trgm'
    AND installed_version IS NOT NULL;

    # If the extension is enabled this will produce the following output:
    enabled
    ---------
     t
    (1 row)

    # Quit the database session
    gitlabhq_production> \q

    # Connect as superuser to gitlab db and enable pg_trgm extension
    psql -U pgsql -d gitlabhq_production -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

## 3. Redis

Redis is automatically installed, when installing Gitlab. But some configuration is needed.
The following steps must be done as superuser!

    # Enable Redis socket
    echo 'unixsocket /var/run/redis/redis.sock' >> /usr/local/etc/redis.conf

    # Grant permission to the socket to all members of the redis group
    echo 'unixsocketperm 770' >> /usr/local/etc/redis.conf

    # Allow Redis to be started
    sysrc redis_enable=YES

    # Activate the changes to redis.conf
    service redis restart

    # Add git user to redis group
    pw groupmod redis -m git

## 4. GitLab

### Change home directory of git user

Currently the default home directory of the git user used by FreeBSD is /usr/local/git.
But GitLab expects /home/git. As long as you do not use the port devel/py-gitosis it is
save to change the home directory:

    # You need to be root user
    vipw -d /etc
    
    # find this line:
    git:*:211:211::0:0:gitosis user:/usr/local/git:/bin/sh
    
    # replace it with this line:
    git:*:211:211::0:0:gitosis user:/usr/home/git:/bin/sh

### Configure It

    # You need to be root user

    # Go to GitLab installation folder
    cd /usr/local/www/gitlab

    # Update GitLab config file, follow the directions at the top of the file
    vi config/gitlab.yml

    # Find number of cores
    sysctl hw.ncpu

    # Enable cluster mode if you expect to have a high load instance
    # Ex. change amount of workers to 3 for 2GB RAM server
    # Set the number of workers to at least the number of cores
    vi config/unicorn.rb

    # Configure Git global settings for git user
    # 'autocrlf' is needed for the web editor
    git config --global core.autocrlf input

    # Disable 'git gc --auto' because GitLab already runs 'git gc' when needed
    git config --global gc.auto 0

    # Enable packfile bitmaps
    git config --global repack.writeBitmaps true

**Important Note:** Make sure to edit both `gitlab.yml` and `unicorn.rb` to match your setup.

**Note:** If you want to use HTTPS, see [Using HTTPS](#using-https) for the additional steps.

### Configure GitLab DB Settings

    # Remote PostgreSQL only:
    # Update username/password in config/database.yml.
    # You only need to adapt the production settings (first part).
    # If you followed the database guide then please do as follows:
    # Change 'secure password' with the value you have given to $password
    # You can keep the double quotes around the password
    vi config/database.yml

### Initialize Database and Activate Advanced Features

    # make sure you are still using the root user and in /usr/local/www/gitlab
    rake gitlab:setup RAILS_ENV=production

    # Type 'yes' to create the database tables.

    # When done you see 'Administrator account created:'

**Note:** You can set the Administrator/root password by supplying it in environmental variable `GITLAB_ROOT_PASSWORD` as seen below. If you don't set the password (and it is set to the default one) please wait with exposing GitLab to the public internet until the installation is done and you've logged into the server the first time. During the first login you'll be forced to change the default password.

    rake gitlab:setup RAILS_ENV=production GITLAB_ROOT_PASSWORD=yourpassword

### Secure secrets.yml

The `secrets.yml` file stores encryption keys for sessions and secure variables.
Backup `secrets.yml` someplace safe, but don't store it in the same place as your database backups.
Otherwise your secrets are exposed if one of your backups is compromised.

### Check Application Status

Check if GitLab and its environment are configured correctly:

    rake gitlab:env:info RAILS_ENV=production

### Compile Assets

    rake assets:precompile RAILS_ENV=production

### Start Your GitLab Instance

    # use this command as root user to start gitlab:
    service gitlab start
    # or this:
    /usr/local/etc/rc.d/gitlab restart

## 7. Nginx

**Note:** Nginx is the officially supported web server for GitLab. If you cannot or do not want to use Nginx as your web server, have a look at the [GitLab recipes](https://gitlab.com/gitlab-org/gitlab-recipes/).

### Installation

    pkg install nginx

    # create nginx log directory
    mkdir /var/log/nginx

### Site Configuration

Just include the provided configuration in your nginx configuration.

    # do this as root:
    vi /usr/local/etc/nginx/nginx.conf

    # within the 'http' configuration block add:
    include       /usr/local/www/gitlab/lib/support/nginx/gitlab;

**Note:** If you want to use HTTPS, replace the `gitlab` Nginx config with `gitlab-ssl`. See [Using HTTPS](#using-https) for HTTPS configuration details.

### Test Configuration

Validate your `gitlab` or `gitlab-ssl` Nginx config file with the following command:

    # do this as root:
    nginx -t

You should receive `syntax is okay` and `test is successful` messages. If you receive errors check your `gitlab` or `gitlab-ssl` Nginx config file for typos, etc. as indicated in the error message given.

### Restart

    service nginx restart

## Done!

### Double-check Application Status

To make sure you didn't miss anything run a more thorough check with:

    su
    su git
    rake gitlab:check RAILS_ENV=production

If all items are green, then congratulations on successfully installing GitLab!

NOTE: Supply `SANITIZE=true` environment variable to `gitlab:check` to omit project names from the output of the check command.

### Initial Login

Visit YOUR_SERVER in your web browser for your first GitLab login.

If you didn't [provide a root password during setup](#initialize-database-and-activate-advanced-features),
you'll be redirected to a password reset screen to provide the password for the
initial administrator account. Enter your desired password and you'll be
redirected back to the login screen.

The default account's username is **root**. Provide the password you created
earlier and login. After login you can change the username if you wish.

**Enjoy!**

You can use as root `service gitlab start` and `service gitlab stop` to start and stop GitLab.

## Advanced Setup Tips

### Using HTTPS

To use GitLab with HTTPS:

1. In `gitlab.yml`:
    1. Set the `port` option in section 1 to `443`.
    1. Set the `https` option in section 1 to `true`.
1. In the `config.yml` of gitlab-shell:
    1. Set `gitlab_url` option to the HTTPS endpoint of GitLab (e.g. `https://git.example.com`).
    1. Set the certificates using either the `ca_file` or `ca_path` option.
1. Use the `gitlab-ssl` Nginx example config instead of the `gitlab` config.
    1. Update `YOUR_SERVER_FQDN`.
    1. Update `ssl_certificate` and `ssl_certificate_key`.
    1. Review the configuration file and consider applying other security and performance enhancing features.

Using a self-signed certificate is discouraged but if you must use it follow the normal directions then:

1. Generate a self-signed SSL certificate:

    mkdir -p /usr/local/etc/nginx/ssl/
    cd /usr/local/etc/nginx/ssl/
    openssl req -newkey rsa:2048 -x509 -nodes -days 3560 -out gitlab.crt -keyout gitlab.key
    chmod o-r gitlab.key

1. In the `config.yml` of gitlab-shell set `self_signed_cert` to `true`.

### Additional Markup Styles

Apart from the always supported markdown style there are other rich text files that GitLab can display. But you might have to install a dependency to do so. Please see the [github-markup gem readme](https://github.com/gitlabhq/markup#markups) for more information.

### Adding your Trusted Proxies

If you are using a reverse proxy on an separate machine, you may want to add the
proxy to the trusted proxies list. Otherwise users will appear signed in from the
proxy's IP address.

You can add trusted proxies in `config/gitlab.yml` by customizing the `trusted_proxies`
option in section 1. Save the file and restart GitLab for the changes to take effect.

### Custom Redis Connection

If you'd like Resque to connect to a Redis server on a non-standard port or on a different host, you can configure its connection string via the `config/resque.yml` file.

    # example
    production: redis://redis.example.tld:6379

If you want to connect the Redis server via socket, then use the "unix:" URL scheme and the path to the Redis socket file in the `config/resque.yml` file.

    # example
    production: unix:/path/to/redis/socket

Also you can use environment variables in the `config/resque.yml` file:

    # example
    production:
      url: <%= ENV.fetch('GITLAB_REDIS_URL') %>


### Custom SSH Connection

If you are running SSH on a non-standard port, you must change the GitLab user's SSH config.

    # Add to /home/git/.ssh/config
    host localhost          # Give your setup a name (here: override localhost)
        user git            # Your remote git user
        port 2222           # Your port number
        hostname 127.0.0.1; # Your server name or IP

You also need to change the corresponding options (e.g. `ssh_user`, `ssh_host`, `admin_uri`) in the `config\gitlab.yml` file.

### LDAP Authentication

You can configure LDAP authentication in `config/gitlab.yml`. Please restart GitLab after editing this file. This requires building gitlab from the ports-tree with the needed option selected.

### Using Custom Omniauth Providers

See the [omniauth integration document](../integration/omniauth.md). This requires building gitlab from the ports-tree with the needed options selected.
