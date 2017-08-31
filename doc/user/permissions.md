# Permissions

Users have different abilities depending on the access level they have in a
particular group or project. If a user is both in a group's project and the
project itself, the highest permission level is used.

On public and internal projects the Guest role is not enforced. All users will
be able to create issues, leave comments, and clone or download the project code.

When a member leaves the team all the assigned [Issues](project/issues/index.md) and [Merge Requests](project/merge_requests/index.md)
will be unassigned automatically.

GitLab [administrators](../README.md#administrator-documentation) receive all permissions.

To add or import a user, you can follow the
[project members documentation](../user/project/members/index.md).

## Project members permissions

The following table depicts the various user permission levels in a project.

| Action                                | Guest   | Reporter   | Developer   | Master   | Owner  |
|---------------------------------------|---------|------------|-------------|----------|--------|
| Create new issue                      | ✓       | ✓          | ✓           | ✓        | ✓      |
| Create confidential issue             | ✓       | ✓          | ✓           | ✓        | ✓      |
| View confidential issues              | (✓) [^1] | ✓          | ✓           | ✓        | ✓      |
| Leave comments                        | ✓       | ✓          | ✓           | ✓        | ✓      |
| See a list of jobs                    | ✓ [^2]  | ✓          | ✓           | ✓        | ✓      |
| See a job   log                       | ✓ [^2]  | ✓          | ✓           | ✓        | ✓      |
| Download and browse job artifacts     | ✓ [^2]  | ✓          | ✓           | ✓        | ✓      |
| View wiki pages                       | ✓       | ✓          | ✓           | ✓        | ✓      |
| Pull project code                     |         | ✓          | ✓           | ✓        | ✓      |
| Download project                      |         | ✓          | ✓           | ✓        | ✓      |
| Create code snippets                  |         | ✓          | ✓           | ✓        | ✓      |
| Manage issue tracker                  |         | ✓          | ✓           | ✓        | ✓      |
| Manage labels                         |         | ✓          | ✓           | ✓        | ✓      |
| See a commit status                   |         | ✓          | ✓           | ✓        | ✓      |
| See a container registry              |         | ✓          | ✓           | ✓        | ✓      |
| See environments                      |         | ✓          | ✓           | ✓        | ✓      |
| Create new environments               |         |            | ✓           | ✓        | ✓      |
| Use environment terminals             |         |            |             | ✓        | ✓      |
| Stop environments                     |         |            | ✓           | ✓        | ✓      |
| See a list of merge requests          |         | ✓          | ✓           | ✓        | ✓      |
| Manage/Accept merge requests          |         |            | ✓           | ✓        | ✓      |
| Create new merge request              |         |            | ✓           | ✓        | ✓      |
| Create new branches                   |         |            | ✓           | ✓        | ✓      |
| Push to non-protected branches        |         |            | ✓           | ✓        | ✓      |
| Force push to non-protected branches  |         |            | ✓           | ✓        | ✓      |
| Remove non-protected branches         |         |            | ✓           | ✓        | ✓      |
| Add tags                              |         |            | ✓           | ✓        | ✓      |
| Write a wiki                          |         |            | ✓           | ✓        | ✓      |
| Cancel and retry jobs                 |         |            | ✓           | ✓        | ✓      |
| Create or update commit status        |         |            | ✓           | ✓        | ✓      |
| Update a container registry           |         |            | ✓           | ✓        | ✓      |
| Remove a container registry image     |         |            | ✓           | ✓        | ✓      |
| Create new milestones                 |         |            |             | ✓        | ✓      |
| Add new team members                  |         |            |             | ✓        | ✓      |
| Push to protected branches            |         |            |             | ✓        | ✓      |
| Enable/disable branch protection      |         |            |             | ✓        | ✓      |
| Turn on/off protected branch push for devs|         |            |             | ✓        | ✓      |
| Enable/disable tag protections        |         |            |             | ✓        | ✓      |
| Rewrite/remove Git tags               |         |            |             | ✓        | ✓      |
| Edit project                          |         |            |             | ✓        | ✓      |
| Add deploy keys to project            |         |            |             | ✓        | ✓      |
| Configure project hooks               |         |            |             | ✓        | ✓      |
| Manage runners                        |         |            |             | ✓        | ✓      |
| Manage job triggers                   |         |            |             | ✓        | ✓      |
| Manage variables                      |         |            |             | ✓        | ✓      |
| Manage pages                          |         |            |             | ✓        | ✓      |
| Manage pages domains and certificates |         |            |             | ✓        | ✓      |
| Switch visibility level               |         |            |             |          | ✓      |
| Transfer project to another namespace |         |            |             |          | ✓      |
| Remove project                        |         |            |             |          | ✓      |
| Force push to protected branches [^3] |         |            |             |          |        |
| Remove protected branches [^3]        |         |            |             |          |        |
| Remove pages                          |         |            |             |          | ✓      |

## Project features permissions

### Wiki and issues

Project features like wiki and issues can be hidden from users depending on
which visibility level you select on project settings.

- Disabled: disabled for everyone
- Only team members: only team members will see even if your project is public or internal
- Everyone with access: everyone can see depending on your project visibility level

### Protected branches

To prevent people from messing with history or pushing code without
review, we've created protected branches. Read through the documentation on
[protected branches](project/protected_branches.md)
to learn more.

Additionally, you can allow or forbid users with Master and/or
Developer permissions to push to a protected branch. Read through the documentation on
[Allowed to Merge and Allowed to Push settings](project/protected_branches.md#using-the-allowed-to-merge-and-allowed-to-push-settings)
to learn more.

### Cycle Analytics permissions

Find the current permissions on the Cycle Analytics dashboard on
the [documentation on Cycle Analytics permissions](project/cycle_analytics.md#permissions).

### Issue Board permissions

Developers and users with higher permission level can use all
the functionality of the Issue Board, that is create/delete lists
and drag issues around. Read though the
[documentation on Issue Boards permissions](project/issue_board.md#permissions)
to learn more.

### File Locking permissions (EEP)

The user that locks a file or directory is the only one that can edit and push their changes back to the repository where the locked objects are located.

Read through the documentation on [permissions for File Locking](https://docs.gitlab.com/ee/user/project/file_lock.html#permissions-on-file-locking) to learn more.

File Locking is available in
[GitLab Enterprise Edition Premium](https://about.gitlab.com/gitlab-ee/) only.

### Confidential Issues permissions

Confidential issues can be accessed by reporters and higher permission levels,
as well as by guest users that create a confidential issue. To learn more,
read through the documentation on [permissions and access to confidential issues](project/issues/confidential_issues.md#permissions-and-access-to-confidential-issues).

## Group members permissions

Any user can remove themselves from a group, unless they are the last Owner of
the group. The following table depicts the various user permission levels in a
group.

| Action                  | Guest | Reporter | Developer | Master | Owner |
|-------------------------|-------|----------|-----------|--------|-------|
| Browse group            | ✓     | ✓        | ✓         | ✓      | ✓     |
| Edit group              |       |          |           |        | ✓     |
| Create subgroup         |       |          |           |        | ✓     |
| Create project in group |       |          |           | ✓      | ✓     |
| Manage group members    |       |          |           |        | ✓     |
| Remove group            |       |          |           |        | ✓     |
| Manage group labels     |       | ✓        | ✓         | ✓      | ✓     |

### Subgroup permissions

When you add a member to a subgroup, they inherit the membership and
permission level from the parent group. This model allows access to
nested groups if you have membership in one of its parents.

To learn more, read through the documentation on
[subgroups memberships](group/subgroups/index.md#membership).

## External users permissions

In cases where it is desired that a user has access only to some internal or
private projects, there is the option of creating **External Users**. This
feature may be useful when for example a contractor is working on a given
project and should only have access to that project.

External users can only access projects to which they are explicitly granted
access, thus hiding all other internal or private ones from them. Access can be
granted by adding the user as member to the project or group.

They will, like usual users, receive a role in the project or group with all
the abilities that are mentioned in the table above. They cannot however create
groups or projects, and they have the same access as logged out users in all
other cases.

An administrator can flag a user as external [through the API](../api/users.md)
or by checking the checkbox on the admin panel. As an administrator, navigate
to **Admin > Users** to create a new user or edit an existing one. There, you
will find the option to flag the user as external.

By default new users are not set as external users. This behavior can be changed
by an administrator under **Admin > Application Settings**.

## GitLab CI/CD permissions

GitLab CI/CD permissions rely on the role the user has in GitLab. There are four
permission levels in total:

- admin
- master
- developer
- guest/reporter

The admin user can perform any action on GitLab CI/CD in scope of the GitLab
instance and project. In addition, all admins can use the admin interface under
`/admin/runners`.

| Action                                | Guest, Reporter | Developer   | Master   | Admin  |
|---------------------------------------|-----------------|-------------|----------|--------|
| See commits and jobs                  | ✓               | ✓           | ✓        | ✓      |
| Retry or cancel job                   |                 | ✓           | ✓        | ✓      |
| Remove project                        |                 |             | ✓        | ✓      |
| Create project                        |                 |             | ✓        | ✓      |
| Change project configuration          |                 |             | ✓        | ✓      |
| Add specific runners                  |                 |             | ✓        | ✓      |
| Add shared runners                    |                 |             |          | ✓      |
| See events in the system              |                 |             |          | ✓      |
| Admin interface                       |                 |             |          | ✓      |

### Job permissions

>**Note:**
GitLab 8.12 has a completely redesigned job permissions system.
Read all about the [new model and its implications][new-mod].

This table shows granted privileges for jobs triggered by specific types of
users:

| Action                                      | Guest, Reporter | Developer   | Master   | Admin  |
|---------------------------------------------|-----------------|-------------|----------|--------|
| Run CI job                                  |                 | ✓           | ✓        | ✓      |
| Clone source and LFS from current project   |                 | ✓           | ✓        | ✓      |
| Clone source and LFS from public projects   |                 | ✓           | ✓        | ✓      |
| Clone source and LFS from internal projects |                 | ✓ [^4]      | ✓ [^4]   | ✓      |
| Clone source and LFS from private projects  |                 | ✓ [^5]      | ✓ [^5]   | ✓ [^5] |
| Push source and LFS                         |                 |             |          |        |
| Pull container images from current project  |                 | ✓           | ✓        | ✓      |
| Pull container images from public projects  |                 | ✓           | ✓        | ✓      |
| Pull container images from internal projects|                 | ✓ [^4]      | ✓ [^4]   | ✓      |
| Pull container images from private projects |                 | ✓ [^5]      | ✓ [^5]   | ✓ [^5] |
| Push container images to current project    |                 | ✓           | ✓        | ✓      |
| Push container images to other projects     |                 |             |          |        |

### New CI job permissions model

GitLab 8.12 has a completely redesigned job permissions system. To learn more,
read through the documentation on the [new CI/CD permissions model](project/new_ci_build_permissions_model.md#new-ci-job-permissions-model).

## LDAP users permissions

Since GitLab 8.15, LDAP user permissions can now be manually overridden by an admin user.
Read through the documentation on [LDAP users permissions](https://docs.gitlab.com/ee/articles/how_to_configure_ldap_gitlab_ee/index.html#updating-user-permissions-new-feature) to learn more.

## Auditor users permissions (EEP)

An Auditor user should be able to access all projects and groups of a GitLab instance
with the permissions described on the documentation on [auditor users permissions](https://docs.gitlab.com/ee/administration/auditor_users.html#permissions-and-restrictions-of-an-auditor-user).

Auditor users are available in [GitLab Enterprise Edition Premium](https://about.gitlab.com/gitlab-ee/)
only.

----

[^1]: Guest users can only view the confidential issues they created themselves
[^2]: If **Public pipelines** is enabled in **Project Settings > Pipelines**
[^3]: Not allowed for Guest, Reporter, Developer, Master, or Owner
[^4]: Only if user is not external one.
[^5]: Only if user is a member of the project.
[ce-18994]: https://gitlab.com/gitlab-org/gitlab-ce/issues/18994
[new-mod]: project/new_ci_build_permissions_model.md
