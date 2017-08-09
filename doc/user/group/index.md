# Groups

With GitLab Groups you can assemble related projects together
and grant members access to several projects at once.

Groups can also be nested in [subgroups](subgroups/index.md).

Find your groups by expanding the left menu and clicking **Groups**:

![GitLab Groups](img/groups.png)

The Groups page displays all groups you are a member of, how many projects it holds,
how many members it has, the group visibility, and, if you have enough permissions,
a link to the group settings. By clicking the last button you can leave that group.

## Use cases

You can create groups for numerous reasons. To name a few:

- Organize related projects under the same [namespace](#namespaces), add members to that
group and grant access to all their projects at once
- Create a group, include members of your team, and make it easier to
`@mention` all the team at once in issues and merge requests
  - Create a group for your company members, and create [subgroups](subgroups/index.md)
  for each individual team. Let's say you create a group called `company-team`, and among others,
      you created subgroups in this group for each individual team `backend-team`,
      `frontend-team`, and `production-team`:
        1. When you start a new implementation from an issue, you add a comment:
        _"`@company-team`, let's do it! `@company-team/backend-team` you're good to go!"_
        1. When your backend team needs help from frontend, they add a comment:
        _"`@company-team/frontend-team` could you help us here please?"_
        1. When the frontend team completes their implementation, they comment:
        _"`@company-team/backend-team`, it's done! Let's ship it `@company-team/production-team`!"_

## Namespaces

In GitLab, a namespace is a unique name to be used as a user name, a group name, or a subgroup name.

- `http://gitlab.example.com/username`
- `http://gitlab.example.com/groupname`
- `http://gitlab.example.com/groupname/subgroup_name`

For example, consider a user called John:

1. John creates his account on GitLab.com with the username `john`;
his profile will be accessed under `https://gitlab.example.com/john`
1. John creates a group for his team with the groupname `john-team`;
his group and its projects will be accessed under `https://gitlab.example.com/john-team`
1. John creates a subgroup of `john-team` with the subgroup name `marketing`;
his subgroup and its projects will be accessed under `https://gitlab.example.com/john-team/marketing`

By doing so:

- Any team member mentions John with `@john`
- John mentions everyone from his team with `@john-team`
- John mentions only his marketing team with `@john-team/marketing`

## Create a new group

You can create a group in GitLab from:

1. The Groups page: expand the left menu, click **Groups**, and click the green button **New group**:

    ![new group from groups page](img/new_group_from_groups.png)

1. Elsewhere: expand the `plus` sign button on the top navbar and choose **New group**:

    ![new group from elsewhere](img/new_group_from_other_pages.png)

Add the following information:

![new group info](img/create_new_group_info.png)

1. Set the **Group path** which will be the **namespace** under which your projects
   will be hosted (path can contain only letters, digits, underscores, dashes
   and dots; it cannot start with dashes or end in dot).
1. The **Group name** will populate with the path. Optionally, you can change
   it. This is the name that will display in the group views.
1. Optionally, you can add a description so that others can briefly understand
   what this group is about.
1. Optionally, choose an avatar for your project.
1. Choose the [visibility level](../../public_access/public_access.md).

## Add users to a group

Add members to a group by navigating to the group's dashboard, and clicking **Members**:

![add members to group](img/add_new_members.png)

Select the [permission level][permissions] and add the new member. You can also set the expiring
date for that user, from which they will no longer have access to your group.

One of the benefits of putting multiple projects in one group is that you can
give a user to access to all projects in the group with one action.

Consider we have a group with two projects:

- On the **Group Members** page we can now add a new user to the group.
- Now because this user is a **Developer** member of the group, he automatically
gets **Developer** access to **all projects** within that group.

If necessary, you can increase the access level of an individual user for a specific project,
by adding them again as a new member to the project with the new permission levels.

## Request access to a group

As a group owner you can enable or disable non members to request access to
your group. Go to the group settings and click on **Allow users to request access**.

As a user, you can request to be a member of a group. Go to the group you'd
like to be a member of, and click the **Request Access** button on the right
side of your screen.

![Request access button](img/request_access_button.png)

---

Group owners and masters will be notified of your request and will be able to approve or
decline it on the members page.

![Manage access requests](img/access_requests_management.png)

---

If you change your mind before your request is approved, just click the
**Withdraw Access Request** button.

![Withdraw access request button](img/withdraw_access_request_button.png)

## Add projects to a group

There are two different ways to add a new project to a group:

- Select a group and then click on the **New project** button.

    ![New project](img/create_new_project_from_group.png)

    You can then continue on [creating a project](../../gitlab-basics/create-project.md).

- While you are creating a project, select a group namespace
  you've already created from the dropdown menu.

    ![Select group](img/select_group_dropdown.png)

## Transfer an existing project into a group

You can transfer an existing project into a group as long as you have at least **Master** [permissions][permissions] to that group
and if you are an **Owner** of the project.

![Transfer a project to a new namespace](img/transfer_project_to_other_group.png)

Find this option under your project's settings.

GitLab administrators can use the admin interface to move any project to any namespace if needed.

## Manage group memberships via LDAP

In GitLab Enterprise Edition it is possible to manage GitLab group memberships using LDAP groups.
See [the GitLab Enterprise Edition documentation](../../integration/ldap.md) for more information.

## Group settings

Once you have created a group, you can manage its settings by navigating to
the group's dashboard, and clicking **Settings**.

![group settings](img/group_settings.png)

### General settings

Besides giving you the option to edit any settings you've previously
set when [creating the group](#create-a-new-group), you can also
access further configurations for your group.

#### Enforce 2FA to group members

Add a secury layer to your group by
[enforcing two-factor authentication (2FA)](../../security/two_factor_authentication.md#enforcing-2fa-for-all-users-in-a-group)
to all group members.

#### Member Lock (EES/EEP)

Available in [GitLab Enterprise Edition Starter](https://about.gitlab.com/gitlab-ee/),
with **Member Lock** it is possible to lock membership in project to the
level of members in group.

Learn more about [Member Lock](https://docs.gitlab.com/ee/user/group/index.html#member-lock-ees-eep).

#### Share with group lock (EES/EEP)

In [GitLab Enterprise Edition Starter](https://about.gitlab.com/gitlab-ee/)
it is possible to prevent projects in a group from [sharing
a project with another group](../../workflow/share_projects_with_other_groups.md).
This allows for tighter control over project access.

Learn more about [Share with group lock](https://docs.gitlab.com/ee/user/group/index.html#share-with-group-lock-ees-eep).

### Advanced settings

- **Projects**: view all projects within that group, add members to each project,
access each project's settings, and remove any project from the same screen.
- **Webhooks**: configure [webhooks](../project/integrations/webhooks.md)
and [push rules](https://docs.gitlab.com/ee/push_rules/push_rules.html#push-rules) to your group (Push Rules is available in [GitLab Enteprise Edition Starter][ee].)
- **Audit Events**: view [Audit Events](https://docs.gitlab.com/ee/administration/audit_events.html#audit-events)
for the group (GitLab admins only, available in [GitLab Enterprise Edition Starter][ee]).
- **Pipelines quota**: keep track of the [pipeline quota](../admin_area/settings/continuous_integration.md) for the group

[permissions]: ../permissions.md#permissions
[ee]: https://about.gitlab.com/products/