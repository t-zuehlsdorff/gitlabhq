/* global Flash */
import '~/flash';
import Visibility from 'visibilityjs';
import Poll from '../../lib/utils/poll';
import emptyState from '../components/empty_state.vue';
import errorState from '../components/error_state.vue';
import loadingIcon from '../../vue_shared/components/loading_icon.vue';
import pipelinesTableComponent from '../components/pipelines_table.vue';
import eventHub from '../event_hub';

export default {
  components: {
    pipelinesTableComponent,
    errorState,
    emptyState,
    loadingIcon,
  },
  computed: {
    shouldRenderErrorState() {
      return this.hasError && !this.isLoading;
    },
  },
  data() {
    return {
      isLoading: false,
      hasError: false,
      isMakingRequest: false,
      updateGraphDropdown: false,
      hasMadeRequest: false,
    };
  },
  beforeMount() {
    this.poll = new Poll({
      resource: this.service,
      method: 'getPipelines',
      data: this.requestData ? this.requestData : undefined,
      successCallback: this.successCallback,
      errorCallback: this.errorCallback,
      notificationCallback: this.setIsMakingRequest,
    });

    if (!Visibility.hidden()) {
      this.isLoading = true;
      this.poll.makeRequest();
    } else {
      // If tab is not visible we need to make the first request so we don't show the empty
      // state without knowing if there are any pipelines
      this.fetchPipelines();
    }

    Visibility.change(() => {
      if (!Visibility.hidden()) {
        this.poll.restart();
      } else {
        this.poll.stop();
      }
    });

    eventHub.$on('refreshPipelines', this.fetchPipelines);
    eventHub.$on('postAction', this.postAction);
  },
  beforeDestroy() {
    eventHub.$off('refreshPipelines');
    eventHub.$on('postAction', this.postAction);
  },
  destroyed() {
    this.poll.stop();
  },
  methods: {
    fetchPipelines() {
      if (!this.isMakingRequest) {
        this.isLoading = true;

        this.service.getPipelines(this.requestData)
          .then(response => this.successCallback(response))
          .catch(() => this.errorCallback());
      }
    },
    setCommonData(pipelines) {
      this.store.storePipelines(pipelines);
      this.isLoading = false;
      this.updateGraphDropdown = true;
      this.hasMadeRequest = true;
    },
    errorCallback() {
      this.hasError = true;
      this.isLoading = false;
      this.updateGraphDropdown = false;
    },
    setIsMakingRequest(isMakingRequest) {
      this.isMakingRequest = isMakingRequest;

      if (isMakingRequest) {
        this.updateGraphDropdown = false;
      }
    },
    postAction(endpoint) {
      this.service.postAction(endpoint)
        .then(() => eventHub.$emit('refreshPipelines'))
        .catch(() => new Flash('An error occured while making the request.'));
    },
  },
};
