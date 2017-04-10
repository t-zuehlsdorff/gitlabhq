# Style guides and linting
See the relevant style guides for our guidelines and for information on linting:

## JavaScript
We defer to [Airbnb][airbnb-js-style-guide] on most style-related
conventions and enforce them with eslint.

See [our current .eslintrc][eslintrc] for specific rules and patterns.

### Common

#### ESlint

- **Never** disable eslint rules unless you have a good reason.  You may see a lot of legacy files with `/* eslint-disable some-rule, some-other-rule */` at the top, but legacy files are a special case.  Any time you develop a new feature or refactor an existing one, you should abide by the eslint rules.

- **Never Ever EVER** disable eslint globally for a file

  ```javascript
  // bad
  /* eslint-disable */

  // better
  /* eslint-disable some-rule, some-other-rule */

  // best
  // nothing :)
  ```

- If you do need to disable a rule for a single violation, try to do it as locally as possible

  ```javascript
  // bad
  /* eslint-disable no-new */

  import Foo from 'foo';

  new Foo();

  // better
  import Foo from 'foo';

  // eslint-disable-next-line no-new
  new Foo();
  ```

- When they are needed _always_ place ESlint directive comment blocks on the first line of a script, followed by any global declarations, then a blank newline prior to any imports or code.

  ```javascript
  // bad
  /* global Foo */
  /* eslint-disable no-new */
  import Bar from './bar';

  // good
  /* eslint-disable no-new */
  /* global Foo */

  import Bar from './bar';
  ```

- **Never** disable the `no-undef` rule.  Declare globals with `/* global Foo */` instead.

- When declaring multiple globals, always use one `/* global [name] */` line per variable.

  ```javascript
  // bad
  /* globals Flash, Cookies, jQuery */

  // good
  /* global Flash */
  /* global Cookies */
  /* global jQuery */
  ```

#### Modules, Imports, and Exports
- Use ES module syntax to import modules

  ```javascript
  // bad
  require('foo');

  // good
  import Foo from 'foo';

  // bad
  module.exports = Foo;

  // good
  export default Foo;
  ```

- Relative paths

  Unless you are writing a test, always reference other scripts using relative paths instead of `~`

  In **app/assets/javascripts**:
  ```javascript
  // bad
  import Foo from '~/foo'

  // good
  import Foo from '../foo';
  ```

  In **spec/javascripts**:
  ```javascript
  // bad
  import Foo from '../../app/assets/javascripts/foo'

  // good
  import Foo from '~/foo';
  ```

- Avoid using IIFE. Although we have a lot of examples of files which wrap their contents in IIFEs (immediately-invoked function expressions), this is no longer necessary after the transition from Sprockets to webpack. Do not use them anymore and feel free to remove them when refactoring legacy code.

- Avoid adding to the global namespace.

  ```javascript
  // bad
  window.MyClass = class { /* ... */ };

  // good
  export default class MyClass { /* ... */ }
  ```

- Side effects are forbidden in any script which contains exports

  ```javascript
  // bad
  export default class MyClass { /* ... */ }

  document.addEventListener("DOMContentLoaded", function(event) {
    new MyClass();
  }
  ```


#### Data Mutation and Pure functions
- Strive to write many small pure functions, and minimize where mutations occur.

  ```javascript
  // bad
  const values = {foo: 1};

  function impureFunction(items) {
    const bar = 1;

    items.foo = items.a * bar + 2;

    return items.a;
  }

  const c = impureFunction(values);

  // good
  var values = {foo: 1};

  function pureFunction (foo) {
    var bar = 1;

    foo = foo * bar + 2;

    return foo;
  }

  var c = pureFunction(values.foo);
  ```

- Avoid constructors with side-effects


#### Parse Strings into Numbers
- `parseInt()` is preferable over `Number()` or `+`

  ```javascript
  // bad
  +'10' // 10

  // good
  Number('10') // 10

  // better
  parseInt('10', 10);
  ```


### Vue.js


#### Basic Rules
- Only include one Vue.js component per file.
- Export components as plain objects:

  ```javascript
  export default {
    template: `<h1>I'm a component</h1>
  }
  ```

#### Naming
- **Extensions**: Use `.vue` extension for Vue components.
- **Reference Naming**: Use PascalCase for Vue components and camelCase for their instances:
  ```javascript
  // bad
  import cardBoard from 'cardBoard';

  // good
  import CardBoard from 'cardBoard'

  // bad
  components: {
    CardBoard: CardBoard
  };

  // good
  components: {
    cardBoard: CardBoard
  };
  ```
- **Props Naming:**
- Avoid using DOM component prop names.
- Use kebab-case instead of camelCase to provide props in templates.

  ```javascript
  // bad
  <component class="btn">

  // good
  <component css-class="btn">

  // bad
  <component myProp="prop" />

  // good
  <component my-prop="prop" />
```

#### Alignment
- Follow these alignment styles for the template method:

  ```javascript
  // bad
  <component v-if="bar"
      param="baz" />

  // good
  <component
    v-if="bar"
    param="baz"
  />

  // if props fit in one line then keep it on the same line
  <component bar="bar" />
  ```

#### Quotes
- Always use double quotes `"` inside templates and single quotes `'` for all other JS.

  ```javascript
  // bad
  template: `
    <button :class='style'>Button</button>
  `

  // good
  template: `
    <button :class="style">Button</button>
  `
  ```

#### Props
- Props should be declared as an object

  ```javascript
  // bad
  props: ['foo']

  // good
  props: {
    foo: {
      type: String,
      required: false,
      default: 'bar'
    }
  }
  ```

- Required key should always be provided when declaring a prop

  ```javascript
  // bad
  props: {
    foo: {
      type: String,
    }
  }

  // good
  props: {
    foo: {
      type: String,
      required: false,
      default: 'bar'
    }
  }
  ```

- Default key should always be provided if the prop is not required:

  ```javascript
  // bad
  props: {
    foo: {
      type: String,
      required: false,
    }
  }

  // good
  props: {
    foo: {
      type: String,
      required: false,
      default: 'bar'
    }
  }

  // good
  props: {
    foo: {
      type: String,
      required: true
    }
  }
  ```

#### Data
- `data` method should always be a function

  ```javascript
  // bad
  data: {
    foo: 'foo'
  }

  // good
  data() {
    return {
      foo: 'foo'
    };
  }
  ```

#### Directives

- Shorthand `@` is preferable over `v-on`

  ```javascript
  // bad
  <component v-on:click="eventHandler"/>


  // good
  <component @click="eventHandler"/>
  ```

- Shorthand `:` is preferable over `v-bind`

  ```javascript
  // bad
  <component v-bind:class="btn"/>


  // good
  <component :class="btn"/>
  ```

#### Closing tags
- Prefer self closing component tags

  ```javascript
  // bad
  <component></component>

  // good
  <component />
  ```

#### Ordering
- Order for a Vue Component:
  1. `name`
  2. `props`
  3. `data`
  4. `components`
  5. `computedProps`
  6. `methods`
  7. lifecycle methods
    1. `beforeCreate`
    2. `created`
    3. `beforeMount`
    4. `mounted`
    5. `beforeUpdate`
    6. `updated`
    7. `activated`
    8. `deactivated`
    9. `beforeDestroy`
    10. `destroyed`
  8. `template`


## SCSS
- [SCSS](style_guide_scss.md)

[airbnb-js-style-guide]: https://github.com/airbnb/javascript
[eslintrc]: https://gitlab.com/gitlab-org/gitlab-ce/blob/master/.eslintrc
