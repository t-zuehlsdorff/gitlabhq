/* global Flash */

import Vue from 'vue';
import JobMediator from './job_details_mediator';
import jobHeader from './components/header.vue';
import detailsBlock from './components/sidebar_details_block.vue';

document.addEventListener('DOMContentLoaded', () => {
  const dataset = document.getElementById('js-job-details-vue').dataset;
  const mediator = new JobMediator({ endpoint: dataset.endpoint });

  mediator.fetchJob();

  // Header
  // eslint-disable-next-line no-new
  new Vue({
    el: '#js-build-header-vue',
    data() {
      return {
        mediator,
      };
    },
    components: {
      jobHeader,
    },
    mounted() {
      this.mediator.initBuildClass();
    },
    render(createElement) {
      return createElement('job-header', {
        props: {
          isLoading: this.mediator.state.isLoading,
          job: this.mediator.store.state.job,
        },
      });
    },
  });

  // Sidebar information block
  // eslint-disable-next-line
  new Vue({
    el: '#js-details-block-vue',
    data() {
      return {
        mediator,
      };
    },
    components: {
      detailsBlock,
    },
    render(createElement) {
      return createElement('details-block', {
        props: {
          isLoading: this.mediator.state.isLoading,
          job: this.mediator.store.state.job,
        },
      });
    },
  });
});
