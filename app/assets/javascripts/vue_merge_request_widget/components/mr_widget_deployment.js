/* global Flash */

import '~/lib/utils/datetime_utility';
import MemoryUsage from './mr_widget_memory_usage';
import StatusIcon from './mr_widget_status_icon';
import MRWidgetService from '../services/mr_widget_service';

export default {
  name: 'MRWidgetDeployment',
  props: {
    mr: { type: Object, required: true },
    service: { type: Object, required: true },
  },
  components: {
    'mr-widget-memory-usage': MemoryUsage,
    'status-icon': StatusIcon,
  },
  methods: {
    formatDate(date) {
      return gl.utils.getTimeago().format(date);
    },
    hasExternalUrls(deployment = {}) {
      return deployment.external_url && deployment.external_url_formatted;
    },
    hasDeploymentTime(deployment = {}) {
      return deployment.deployed_at && deployment.deployed_at_formatted;
    },
    hasDeploymentMeta(deployment = {}) {
      return deployment.url && deployment.name;
    },
    stopEnvironment(deployment) {
      const msg = 'Are you sure you want to stop this environment?';
      const isConfirmed = confirm(msg); // eslint-disable-line

      if (isConfirmed) {
        MRWidgetService.stopEnvironment(deployment.stop_url)
          .then(res => res.json())
          .then((res) => {
            if (res.redirect_url) {
              gl.utils.visitUrl(res.redirect_url);
            }
          })
          .catch(() => {
            new Flash('Something went wrong while stopping this environment. Please try again.'); // eslint-disable-line
          });
      }
    },
  },
  template: `
    <div class="mr-widget-heading deploy-heading">
      <div v-for="deployment in mr.deployments">
        <div class="ci-widget media">
          <div class="ci-status-icon ci-status-icon-success">
            <span class="js-icon-link icon-link">
              <status-icon status="success" />
            </span>
          </div>
          <div class="media-body space-children">
            <span>
              <span
                v-if="hasDeploymentMeta(deployment)">
                Deployed to
              </span>
              <a
                v-if="hasDeploymentMeta(deployment)"
                :href="deployment.url"
                target="_blank"
                rel="noopener noreferrer nofollow"
                class="js-deploy-meta inline">
                {{deployment.name}}
              </a>
              <span
                v-if="hasExternalUrls(deployment)">
                on
              </span>
              <a
                v-if="hasExternalUrls(deployment)"
                :href="deployment.external_url"
                target="_blank"
                rel="noopener noreferrer nofollow"
                class="js-deploy-url inline">
                <i
                  class="fa fa-external-link"
                  aria-hidden="true" />
                {{deployment.external_url_formatted}}
              </a>
              <span
                v-if="hasDeploymentTime(deployment)"
                :data-title="deployment.deployed_at_formatted"
                class="js-deploy-time"
                data-toggle="tooltip"
                data-placement="top">
                {{formatDate(deployment.deployed_at)}}
              </span>
            </span>
            <button
              type="button"
              v-if="deployment.stop_url"
              @click="stopEnvironment(deployment)"
              class="btn btn-default btn-xs">
              Stop environment
            </button>
            <mr-widget-memory-usage
              v-if="deployment.metrics_url"
              :metrics-url="deployment.metrics_url"
              :metrics-monitoring-url="deployment.metrics_monitoring_url"
            />
          </div>
        </div>
      </div>
    </div>
  `,
};
