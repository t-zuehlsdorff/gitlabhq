# Universal update guide for patch versions
*Make sure you view this [upgrade guide](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/update/freebsd_patch_versions.md) from the `master` branch for the most up to date instructions.*

For example from 7.14.0 to 7.14.3, also see the [semantic versioning specification](http://semver.org/).

### 0. Backup

It's useful to make a backup just in case things go south:
(With MySQL, this may require granting "LOCK TABLES" privileges to the GitLab
user on the database version)

```bash
# make sure you're using the root-user
cd /usr/local/www/gitlab
rake gitlab:backup:create RAILS_ENV=production
```

### 1. Stop server

```bash
# make sure you are still the root-user
service gitlab stop
```

### 2. Get latest packages

If you have installed GitLab by using pkg just enter:

```bash
# make sure you are still the root-user
pkg upgrade
```

This will update *all* of your installed packages, including GitLab
and all of its dependencies.

### 3. Remove Gemfile.lock

Because all dependencies of GitLab are managed by the package manager of FreeBSD,
we need to ignore the Gemfile.lock shipped by GitLab or greated when starting
an older version. It is sufficent to just remove it.

```bash
# make sure you are still the root-user
rm /usr/local/www/gitlab/Gemfile.lock
```

It is possible that an error occurs after the update, because of problems with
the new Gemfile.lock. In this case please write a bug report at:
https://bugs.freebsd.org/bugzilla/enter_bug.cgi?product=Ports%20%26%20Packages
  
### 4. Install libs, migrations, etc.

```bash
# make sure you are still the root-user
cd /usr/local/www/gitlab
rake db:migrate RAILS_ENV=production
rake assets:clean assets:precompile cache:clear RAILS_ENV=production
```

### 6. Start application

```bash
# make sure you are still the root-user
service gitlab start
service nginx restart
```

### 7. Check application status

Check if GitLab and its environment are configured correctly:

```bash
# make sure you are still the root-user
rake gitlab:env:info RAILS_ENV=production
```

To make sure you didn't miss anything run a more thorough check with:

```bash
# make sure you are still the root-user
rake gitlab:check RAILS_ENV=production
```

If all items are green, then congratulations upgrade complete!
