# Components

## Contents
* [Tooltips](#tooltips)
* [Anchor links](#anchor-links)
* [Buttons](#buttons)
* [Dropdowns](#dropdowns)
* [Counts](#counts)
* [Lists](#lists)
* [Tables](#tables)
* [Blocks](#blocks)
* [Panels](#panels)
* [Alerts](#alerts)
* [Forms](#forms)
* [Search box](#search-box)
* [File holders](#file-holders)
* [Data formats](#data-formats)

---

## Tooltips
Tooltips identify elements or provide additional, useful information about the referring elements. Tooltips are different from ALT-attributes, which are intended primarily for static images. Tooltips are summoned by:

* Hovering over an element with a cursor
* Focusing on an element with a keyboard (usually the tab key)
* Upon touch

### Usage
A tooltip should be used:
* When there isn’t enough space to show the information
* When it isn’t critical for the user to see the information
* For icons that don’t have a label

Tooltips shouldn’t repeat information that is shown near the referring element. However, they can show the same data in a different format (e.g. date or timestamps).

![Tooltip usage](img/tooltip-usage.png)

### Placement
By default, tooltips should be placed below the referring element. However, if there isn’t enough space in the viewport, the tooltip should be moved to the side as needed.

![Tooltip placement location](img/tooltip-placement.png)

---

## Anchor links

Anchor links are used for navigational actions and lone, secondary commands (such as 'Reset filters' on the Issues List) when deemed appropriate by the UX team.

### States

#### Rest

Primary links are blue in their rest state. Secondary links (such as the time stamp on comments) are a neutral gray color in rest. Details on the main GitLab navigation links can be found on the [features](features.md#navigation) page.

#### Hover

On hover, an underline should be added and the color should change. Both the primary and secondary link should become the darker blue color on hover.

#### Focus

The focus state should match the hover state.

![Anchor link states ](img/components-anchorlinks.png)

---

## Buttons

Buttons communicate the command that will occur when the user clicks on them.

### Types

#### Primary
Primary buttons communicate the main call to action. There should only be one call to action in any given experience. Visually, primary buttons are conveyed with a full background fill

![Primary button example](img/button-primary.png)

#### Secondary
Secondary buttons are for alternative commands. They should be conveyed by a button with an stroke, and no background fill.

![Secondary button example](img/button-secondary.png)

### Icon and text treatment
Text should be in sentence case, where only the first word is capitalized. "Create issue" is correct, not "Create Issue". Buttons should only contain an icon or a text, not both.

> TODO: Rationalize this. Ensure that we still believe this.

### Colors
The default color treatment is the white/grey button. Follow the guidance on the [basics](basics.md#color) page to add meaningful color to a button.

### Secondary states

Primary buttons darken the color of their background and border for hover, focus and active states. An inner shadow is added to the active state to denote the button being pressed.

| Values | Info | Success | Warning | Danger |
| :------ | :------: | :------: | :------: | :------: |
| Background: `$color-light` <br> Border: `$border-color-light` | ![](img/button-info--resting.png) | ![](img/button-success--resting.png) | ![](img/button-warning--resting.png) | ![](img/button-danger--resting.png) |
| Background: `$color-normal` <br> Border: `$border-color-normal` | ![](img/button-info--hover.png) | ![](img/button-success--hover.png) | ![](img/button-warning--hover.png) | ![](img/button-danger--hover.png) |
| Background: `$color-dark` <br> Border: `$border-color-dark` | ![](img/button-info--active.png) | ![](img/button-success--active.png) | ![](img/button-warning--active.png) | ![](img/button-danger--active.png) |

Since secondary buttons only have a border on their resting state, their hover and focus states add a background color, which gets darkened on active.

| Values | Success Secondary | Close | Spam |
| :------ | :------: | :------: | :------: |
| Font: `$border-color-light` <br> Border: `$border-color-light` | ![](img/button-success-secondary--resting.png) | ![](img/button-close--resting.png) | ![](img/button-spam--resting.png) |
| Background: `$color-light` <br> Border: `$border-color-light` | ![](img/button-success-secondary--hover.png) | ![](img/button-close--hover.png) | ![](img/button-spam--hover.png) |
| Background: `$color-normal` <br> Border: `$border-color-normal` | ![](img/button-success-secondary--active.png) | ![](img/button-close--active.png) | ![](img/button-spam--active.png) |

### Placement

When there are a group of buttons in a dialog or a form, we need to be consistent with the placement.

#### Dismissive actions on the left
The dismissive action returns the user to the previous state.

> Example: Cancel

#### Affirmative actions on the right
Affirmative actions continue to progress towards the user goal that triggered the dialog or form.

> Example: Submit, Ok, Delete

---


## Dropdowns

Dropdowns are used to allow users to choose one (or many) options from a list of options. If this list of options is more 20, there should generally be a way to search through and filter the options (see the complex filter dropdowns below.)

> TODO: Will update this section when the new filters UI is implemented.

![Dropdown states](img/components-dropdown.png)

### Max size

The max height for dropdowns should target **10-15** single line items, or **7-10** multi-line items. If the height of the dropdown is too large, the list becomes very hard to parse and it is easy to visually lose track of the item you are looking for. Usability also suffers as more mouse movement is required, and you have a larger area in which you hijack the scroll away from the page level. While it may initially seem counterintuitive to not show as many items as you can, it is actually quicker and easier to process the information when it is cropped at a reasonable height.

---

## Counts

A count element is used in navigation contexts where it is helpful to indicate the count, or number of items, in a list. Always use the [`number_with_delimiter`][number_with_delimiter] helper to display counts in the UI.

![Counts example](img/components-counts.png)

[number_with_delimiter]: http://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#method-i-number_with_delimiter

---

## Lists

Lists are used where ever there is a single column of information to display. Ths [issues list](https://gitlab.com/gitlab-org/gitlab-ce/issues) is an example of a important list in the GitLab UI.

### Types

Simple list using .content-list

![Simple list](img/components-simplelist.png)

List with avatar, title and description using .content-list

![List with avatar](img/components-listwithavatar.png)

List with hover effect .well-list

![List with hover effect](img/components-listwithhover.png)

List inside panel

![List inside panel](img/components-listinsidepanel.png)

---

## Tables

When the information is too complex for a list, with multiple columns of information, a table can be used. For example, the [pipelines page](https://gitlab.com/gitlab-org/gitlab-ce/pipelines) uses a table.

![Table](img/components-table.png)

---

## Blocks

Blocks are a way to group related information.

### Types

#### Content blocks

Content blocks (`.content-block`) are the basic grouping of content. They are commonly used in [lists](#lists), and are separated by a botton border.

![Content block](img/components-contentblock.png)

#### Row content blocks

A background color can be added to this blocks. For example, items in the [issue list](https://gitlab.com/gitlab-org/gitlab-ce/issues) have a green background if they were created recently. Below is an example of a gray content block with side padding using `.row-content-block`.

![Row content block](img/components-rowcontentblock.png)

#### Cover blocks
Cover blocks are generally used to create a heading element for a page, such as a new project, or a user profile page. Below is a cover block (`.cover-block`) for the profile page with an avatar, name and description.

![Cover block](img/components-coverblock.png)

---

## Panels

> TODO: Catalog how we are currently using panels and rationalize how they relate to alerts

![Panels](img/components-panels.png)

---

## Alerts

> TODO: Catalog how we are currently using alerts

![Alerts](img/components-alerts.png)

---

## Forms

There are two options shown below regarding the positioning of labels in forms. Both are options to consider based on context and available size. However, it is important to have a consistent treatment of labels in the same form.

### Types

#### Labels stack vertically

Form (`form`) with label rendered above input.

![Vertical form](img/components-verticalform.png)

#### Labels side-by-side

Horizontal form (`form.horizontal-form`) with label rendered inline with input.

![Horizontal form](img/components-horizontalform.png)

---

## Search box

Search boxes across GitLab have a consistent rest, active and text entered state. When text isn't entered in the box, there should be a magnifying glass right aligned with the input field. When text is entered, the magnifying glass should become a x, allowing users to clear their text.

![Search box](img/components-searchbox.png)

If needed, we indicate the scope of the search in the search box.

![Scoped Search box](img/components-searchboxscoped.png)

---

## File holders
A file holder (`.file-holder`) is used to show the contents of a file inline on a page of GitLab.

![File Holder component](img/components-fileholder.png)

---

## Data formats

### Dates

#### Exact

Format for exacts dates should be ‘Mon DD, YYYY’, such as the examples below.

![Exact date](img/components-dateexact.png)

#### Relative

This format relates how long since an action has occurred. The exact date can be shown as a tooltip on hover.

![Relative date](img/components-daterelative.png)

### References

Referencing GitLab items depends on a symbol for each type of item. Typing that symbol will invoke a dropdown that allows you to search for and autocomplete the item you were looking for. References are shown as [links](#links) in context, and hovering on them shows the full title or name of the item.

![Hovering on a reference](img/components-referencehover.png)

#### `%` Milestones

![Milestone reference](img/components-referencemilestone.png)

#### `#` Issues

![Issue reference](img/components-referenceissues.png)

#### `!` Merge Requests

![Merge request reference](img/components-referencemrs.png)

#### `~` Labels

![Labels reference](img/components-referencelabels.png)

#### `@` People

![People reference](img/components-referencepeople.png)

> TODO: Open issue: Some commit references use monospace fonts, but others don't. Need to standardize this.
