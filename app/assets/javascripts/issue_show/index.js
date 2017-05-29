import Vue from 'vue';
import issuableApp from './components/app.vue';
import '../vue_shared/vue_resource_interceptor';

document.addEventListener('DOMContentLoaded', () => new Vue({
  el: document.getElementById('js-issuable-app'),
  components: {
    issuableApp,
  },
  data() {
    const issuableElement = this.$options.el;
    const issuableTitleElement = issuableElement.querySelector('.title');
    const issuableDescriptionElement = issuableElement.querySelector('.wiki');
    const issuableDescriptionTextarea = issuableElement.querySelector('.js-task-list-field');
    const {
      canUpdate,
      endpoint,
      issuableRef,
    } = issuableElement.dataset;

    return {
      canUpdate: gl.utils.convertPermissionToBoolean(canUpdate),
      endpoint,
      issuableRef,
      initialTitle: issuableTitleElement.innerHTML,
      initialDescriptionHtml: issuableDescriptionElement ? issuableDescriptionElement.innerHTML : '',
      initialDescriptionText: issuableDescriptionTextarea ? issuableDescriptionTextarea.textContent : '',
    };
  },
  render(createElement) {
    return createElement('issuable-app', {
      props: {
        canUpdate: this.canUpdate,
        endpoint: this.endpoint,
        issuableRef: this.issuableRef,
        initialTitle: this.initialTitle,
        initialDescriptionHtml: this.initialDescriptionHtml,
        initialDescriptionText: this.initialDescriptionText,
      },
    });
  },
}));
