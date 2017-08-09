import _ from 'underscore';

/**
 * Makes search request for content when user types a value in the search input.
 * Updates the html content of the page with the received one.
 */

export default class FilterableList {
  constructor(form, filter, holder) {
    this.filterForm = form;
    this.listFilterElement = filter;
    this.listHolderElement = holder;
    this.isBusy = false;
  }

  getFilterEndpoint() {
    return `${this.filterForm.getAttribute('action')}?${$(this.filterForm).serialize()}`;
  }

  getPagePath() {
    return this.getFilterEndpoint();
  }

  initSearch() {
    // Wrap to prevent passing event arguments to .filterResults;
    this.debounceFilter = _.debounce(this.onFilterInput.bind(this), 500);

    this.unbindEvents();
    this.bindEvents();
  }

  onFilterInput() {
    const $form = $(this.filterForm);
    const queryData = {};
    const filterGroupsParam = $form.find('[name="filter_groups"]').val();

    if (filterGroupsParam) {
      queryData.filter_groups = filterGroupsParam;
    }

    this.filterResults(queryData);

    if (this.setDefaultFilterOption) {
      this.setDefaultFilterOption();
    }
  }

  bindEvents() {
    this.listFilterElement.addEventListener('input', this.debounceFilter);
  }

  unbindEvents() {
    this.listFilterElement.removeEventListener('input', this.debounceFilter);
  }

  filterResults(queryData) {
    if (this.isBusy) {
      return false;
    }

    $(this.listHolderElement).fadeTo(250, 0.5);

    return $.ajax({
      url: this.getFilterEndpoint(),
      data: queryData,
      type: 'GET',
      dataType: 'json',
      context: this,
      complete: this.onFilterComplete,
      beforeSend: () => {
        this.isBusy = true;
      },
      success: (response, textStatus, xhr) => {
        this.onFilterSuccess(response, xhr, queryData);
      },
    });
  }

  onFilterSuccess(response, xhr, queryData) {
    if (response.html) {
      this.listHolderElement.innerHTML = response.html;
    }

    // Change url so if user reload a page - search results are saved
    const currentPath = this.getPagePath(queryData);

    return window.history.replaceState({
      page: currentPath,
    }, document.title, currentPath);
  }

  onFilterComplete() {
    this.isBusy = false;
    $(this.listHolderElement).fadeTo(250, 1);
  }
}
