import statusCodes from '~/lib/utils/http_status';
import { bytesToMiB } from '~/lib/utils/number_utils';

import MemoryGraph from '../../vue_shared/components/memory_graph';
import MRWidgetService from '../services/mr_widget_service';

export default {
  name: 'MemoryUsage',
  props: {
    metricsUrl: { type: String, required: true },
  },
  data() {
    return {
      memoryFrom: 0,
      memoryTo: 0,
      memoryMetrics: [],
      deploymentTime: 0,
      hasMetrics: false,
      loadFailed: false,
      loadingMetrics: true,
      backOffRequestCounter: 0,
    };
  },
  components: {
    'mr-memory-graph': MemoryGraph,
  },
  computed: {
    shouldShowLoading() {
      return this.loadingMetrics && !this.hasMetrics && !this.loadFailed;
    },
    shouldShowMemoryGraph() {
      return !this.loadingMetrics && this.hasMetrics && !this.loadFailed;
    },
    shouldShowLoadFailure() {
      return !this.loadingMetrics && !this.hasMetrics && this.loadFailed;
    },
    shouldShowMetricsUnavailable() {
      return !this.loadingMetrics && !this.hasMetrics && !this.loadFailed;
    },
    memoryChangeType() {
      const memoryTo = Number(this.memoryTo);
      const memoryFrom = Number(this.memoryFrom);

      if (memoryTo > memoryFrom) {
        return 'increased';
      } else if (memoryTo < memoryFrom) {
        return 'decreased';
      }

      return 'unchanged';
    },
  },
  methods: {
    getMegabytes(bytesString) {
      const valueInBytes = Number(bytesString).toFixed(2);
      return (bytesToMiB(valueInBytes)).toFixed(2);
    },
    computeGraphData(metrics, deploymentTime) {
      this.loadingMetrics = false;
      const { memory_before, memory_after, memory_values } = metrics;

      // Both `memory_before` and `memory_after` objects
      // have peculiar structure where accessing only a specific
      // index yeilds correct value that we can use to show memory delta.
      if (memory_before.length > 0) {
        this.memoryFrom = this.getMegabytes(memory_before[0].value[1]);
      }

      if (memory_after.length > 0) {
        this.memoryTo = this.getMegabytes(memory_after[0].value[1]);
      }

      if (memory_values.length > 0) {
        this.hasMetrics = true;
        this.memoryMetrics = memory_values[0].values;
        this.deploymentTime = deploymentTime;
      }
    },
    loadMetrics() {
      gl.utils.backOff((next, stop) => {
        MRWidgetService.fetchMetrics(this.metricsUrl)
          .then((res) => {
            if (res.status === statusCodes.NO_CONTENT) {
              this.backOffRequestCounter = this.backOffRequestCounter += 1;
              /* eslint-disable no-unused-expressions */
              this.backOffRequestCounter < 3 ? next() : stop(res);
            } else {
              stop(res);
            }
          })
          .catch(stop);
      })
        .then((res) => {
          if (res.status === statusCodes.NO_CONTENT) {
            return res;
          }

          return res.json();
        })
        .then((res) => {
          this.computeGraphData(res.metrics, res.deployment_time);
          return res;
        })
        .catch(() => {
          this.loadFailed = true;
          this.loadingMetrics = false;
        });
    },
  },
  mounted() {
    this.loadingMetrics = true;
    this.loadMetrics();
  },
  template: `
    <div class="mr-info-list clearfix mr-memory-usage js-mr-memory-usage">
      <div class="legend"></div>
      <p
        v-if="shouldShowLoading"
        class="usage-info js-usage-info usage-info-loading">
        <i
          class="fa fa-spinner fa-spin usage-info-load-spinner"
          aria-hidden="true" />Loading deployment statistics.
      </p>
      <p
        v-if="shouldShowMemoryGraph"
        class="usage-info js-usage-info">
        Memory usage <b>{{memoryChangeType}}</b> from {{memoryFrom}}MB to {{memoryTo}}MB
      </p>
      <p
        v-if="shouldShowLoadFailure"
        class="usage-info js-usage-info usage-info-failed">
        Failed to load deployment statistics.
      </p>
      <p
        v-if="shouldShowMetricsUnavailable"
        class="usage-info js-usage-info usage-info-unavailable">
        Deployment statistics are not available currently.
      </p>
      <mr-memory-graph
        v-if="shouldShowMemoryGraph"
        :metrics="memoryMetrics"
        :deploymentTime="deploymentTime"
        height="25"
        width="100" />
    </div>
  `,
};
