# Internationalization for GitLab

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/10669) in GitLab 9.2.

For working with internationalization (i18n) we use
[GNU gettext](https://www.gnu.org/software/gettext/) given it's the most used
tool for this task and we have a lot of applications that will help us to work
with it.

## Setting up GitLab Development Kit (GDK)

In order to be able to work on the [GitLab Community Edition](https://gitlab.com/gitlab-org/gitlab-ce) project we must download and
configure it through [GDK](https://gitlab.com/gitlab-org/gitlab-development-kit), we can do it by following this [guide](https://gitlab.com/gitlab-org/gitlab-development-kit/blob/master/doc/set-up-gdk.md).

Once we have the GitLab project ready we can start working on the
translation of the project.

## Tools

We use a couple of gems:

1. [`gettext_i18n_rails`](https://github.com/grosser/gettext_i18n_rails): this
   gem allow us to translate content from models, views and controllers. Also
   it gives us access to the following raketasks:
    - `rake gettext:find`: Parses almost all the files from the
      Rails application looking for content that has been marked for
      translation. Finally, it updates the PO files with the new content that
      it has found.
    - `rake gettext:pack`: Processes the PO files and generates the
      MO files that are binary and are finally used by the application.

1. [`gettext_i18n_rails_js`](https://github.com/webhippie/gettext_i18n_rails_js):
   this gem is useful to make the translations available in JavaScript. It
   provides the following raketask:
    - `rake gettext:po_to_json`: Reads the contents from the PO files and
      generates JSON files containing all the available translations.

1. PO editor: there are multiple applications that can help us to work with PO
   files, a good option is [Poedit](https://poedit.net/download) which is
   available for macOS, GNU/Linux and Windows.

## Preparing a page for translation

We basically have 4 types of files:

1. Ruby files: basically Models and Controllers.
1. HAML files: these are the view files.
1. ERB files: used for email templates.
1. JavaScript files: we mostly need to work with VUE JS templates.

### Ruby files

If there is a method or variable that works with a raw string, for instance:

```ruby
def hello
  "Hello world!"
end
```

Or:

```ruby
hello = "Hello world!"
```

You can easily mark that content for translation with:

```ruby
def hello
  _("Hello world!")
end
```

Or:

```ruby
hello = _("Hello world!")
```

### HAML files

Given the following content in HAML:

```haml
%h1 Hello world!
```

You can mark that content for translation with:

```haml
%h1= _("Hello world!")
```

### ERB files

Given the following content in ERB:

```erb
<h1>Hello world!</h1>
```

You can mark that content for translation with:

```erb
<h1><%= _("Hello world!") %></h1>
```

### JavaScript files

In JavaScript we added the `__()` (double underscore parenthesis) function
for translations.

### Updating the PO files with the new content

Now that the new content is marked for translation, we need to update the PO
files with the following command:

```sh
bundle exec rake gettext:find
```

This command will update the `locale/**/gitlab.edit.po` file with the
new content that the parser has found.

New translations will be added with their default content and will be marked
fuzzy. To use the translation, look for the `#, fuzzy` mention in `gitlab.edit.po`
and remove it.

Translations that aren't used in the source code anymore will be marked with
`~#`; these can be removed to keep our translation files clutter-free.

## Working with special content

### Interpolation

- In Ruby/HAML:

    ```ruby
    _("Hello %{name}") % { name: 'Joe' }
    ```

- In JavaScript: Not supported at this moment.

### Plurals

- In Ruby/HAML:

    ```ruby
    n_('Apple', 'Apples', 3) => 'Apples'
    ```

    Using interpolation:
    ```ruby
    n_("There is a mouse.", "There are %d mice.", size) % size
    ```

- In JavaScript:

    ```js
    n__('Apple', 'Apples', 3) => 'Apples'
    ```

    Using interpolation:

    ```js
    n__('Last day', 'Last %d days', 30) => 'Last 30 days'
    ```

### Namespaces

Sometimes you need to add some context to the text that you want to translate
(if the word occurs in a sentence and/or the word is ambiguous).

- In Ruby/HAML:

    ```ruby
    s_('OpenedNDaysAgo|Opened')
    ```

    In case the translation is not found it will return `Opened`.

- In JavaScript:

    ```js
    s__('OpenedNDaysAgo|Opened')
    ```

### Just marking content for parsing

Sometimes there are some dynamic translations that can't be found by the
parser when running `bundle exec rake gettext:find`. For these scenarios you can
use the [`_N` method](https://github.com/grosser/gettext_i18n_rails/blob/c09e38d481e0899ca7d3fc01786834fa8e7aab97/Readme.md#unfound-translations-with-rake-gettextfind).

There is also and alternative method to [translate messages from validation errors](https://github.com/grosser/gettext_i18n_rails/blob/c09e38d481e0899ca7d3fc01786834fa8e7aab97/Readme.md#option-a).

## Adding a new language

Let's suppose you want to add translations for a new language, let's say French.

1. The first step is to register the new language in `lib/gitlab/i18n.rb`:

    ```ruby
    ...
    AVAILABLE_LANGUAGES = {
      ...,
      'fr' => 'Français'
    }.freeze
    ...
    ```

1. Next, you need to add the language:

    ```sh
    bundle exec rake gettext:add_language[fr]
    ```

    If you want to add a new language for a specific region, the command is similar,
    you just need to separate the region with an underscore (`_`). For example:

    ```sh
    bundle exec rake gettext:add_language[en_GB]
    ```

    Please note that you need to specify the region part in capitals.

1. Now that the language is added, a new directory has been created under the
   path: `locale/fr/`. You can now start using your PO editor to edit the PO file
   located in: `locale/fr/gitlab.edit.po`.

1. After you're done updating the translations, you need to process the PO files
   in order to generate the binary MO files and finally update the JSON files
   containing the translations:

    ```sh
    bundle exec rake gettext:pack
    bundle exec rake gettext:po_to_json
    ```

1. In order to see the translated content we need to change our preferred language
   which can be found under the user's **Settings** (`/profile`).

1. After checking that the changes are ok, you can proceed to commit the new files.
   For example:

    ```sh
    git add locale/fr/ app/assets/javascripts/locale/fr/
    git commit -m "Add French translations for Cycle Analytics page"
    ```
