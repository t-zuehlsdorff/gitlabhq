import stopwatchSvg from 'icons/_icon_stopwatch.svg';

import '../../../lib/utils/pretty_time';

export default {
  name: 'time-tracking-collapsed-state',
  props: {
    showComparisonState: {
      type: Boolean,
      required: true,
    },
    showSpentOnlyState: {
      type: Boolean,
      required: true,
    },
    showEstimateOnlyState: {
      type: Boolean,
      required: true,
    },
    showNoTimeTrackingState: {
      type: Boolean,
      required: true,
    },
    timeSpentHumanReadable: {
      type: String,
      required: false,
      default: '',
    },
    timeEstimateHumanReadable: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    timeSpent() {
      return this.abbreviateTime(this.timeSpentHumanReadable);
    },
    timeEstimate() {
      return this.abbreviateTime(this.timeEstimateHumanReadable);
    },
    divClass() {
      if (this.showComparisonState) {
        return 'compare';
      } else if (this.showEstimateOnlyState) {
        return 'estimate-only';
      } else if (this.showSpentOnlyState) {
        return 'spend-only';
      } else if (this.showNoTimeTrackingState) {
        return 'no-tracking';
      }

      return '';
    },
    spanClass() {
      if (this.showComparisonState) {
        return '';
      } else if (this.showEstimateOnlyState || this.showSpentOnlyState) {
        return 'bold';
      } else if (this.showNoTimeTrackingState) {
        return 'no-value';
      }

      return '';
    },
    text() {
      if (this.showComparisonState) {
        return `${this.timeSpent} / ${this.timeEstimate}`;
      } else if (this.showEstimateOnlyState) {
        return `-- / ${this.timeEstimate}`;
      } else if (this.showSpentOnlyState) {
        return `${this.timeSpent} / --`;
      } else if (this.showNoTimeTrackingState) {
        return 'None';
      }

      return '';
    },
  },
  methods: {
    abbreviateTime(timeStr) {
      return gl.utils.prettyTime.abbreviateTime(timeStr);
    },
  },
  template: `
    <div class="sidebar-collapsed-icon">
      ${stopwatchSvg}
      <div class="time-tracking-collapsed-summary">
        <div :class="divClass">
          <span :class="spanClass">
            {{ text }}
          </span>
        </div>
      </div>
    </div>
    `,
};
