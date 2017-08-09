// Toggle button. Show/hide content inside parent container.
// Button does not change visibility. If button has icon - it changes chevron style.
//
// %div.js-toggle-container
//   %button.js-toggle-button
//   %div.js-toggle-content
//

$(() => {
  function toggleContainer(container, toggleState) {
    const $container = $(container);

    $container
      .find('.js-toggle-button .fa')
      .toggleClass('fa-chevron-up', toggleState)
      .toggleClass('fa-chevron-down', toggleState !== undefined ? !toggleState : undefined);

    $container
      .find('.js-toggle-content')
      .toggle(toggleState);
  }

  $('body').on('click', '.js-toggle-button', function toggleButton(e) {
    e.target.classList.toggle('open');
    toggleContainer($(this).closest('.js-toggle-container'));

    const targetTag = e.currentTarget.tagName.toLowerCase();
    if (targetTag === 'a' || targetTag === 'button') {
      e.preventDefault();
    }
  });

  // If we're accessing a permalink, ensure it is not inside a
  // closed js-toggle-container!
  const hash = window.gl.utils.getLocationHash();
  const anchor = hash && document.getElementById(hash);
  const container = anchor && $(anchor).closest('.js-toggle-container');

  if (container) {
    toggleContainer(container, true);
    anchor.scrollIntoView();
  }
});
