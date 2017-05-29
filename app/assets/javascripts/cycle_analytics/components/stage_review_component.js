/* eslint-disable no-param-reassign */
import Vue from 'vue';
import userAvatarImage from '../../vue_shared/components/user_avatar/user_avatar_image.vue';

const global = window.gl || (window.gl = {});
global.cycleAnalytics = global.cycleAnalytics || {};

global.cycleAnalytics.StageReviewComponent = Vue.extend({
  props: {
    items: Array,
    stage: Object,
  },
  components: {
    userAvatarImage,
  },
  template: `
    <div>
      <div class="events-description">
        {{ stage.description }}
        <limit-warning :count="items.length" />
      </div>
      <ul class="stage-event-list">
        <li v-for="mergeRequest in items" class="stage-event-item">
          <div class="item-details">
            <!-- FIXME: Pass an alt attribute here for accessibility -->
            <user-avatar-image :img-src="mergeRequest.author.avatarUrl"/>
            <h5 class="item-title merge-merquest-title">
              <a :href="mergeRequest.url">
                {{ mergeRequest.title }}
              </a>
            </h5>
            <a :href="mergeRequest.url" class="issue-link">!{{ mergeRequest.iid }}</a>
            &middot;
            <span>
              {{ s__('OpenedNDaysAgo|Opened') }}
              <a :href="mergeRequest.url" class="issue-date">{{ mergeRequest.createdAt }}</a>
            </span>
            <span>
              {{ s__('ByAuthor|by') }}
              <a :href="mergeRequest.author.webUrl" class="issue-author-link">{{ mergeRequest.author.name }}</a>
            </span>
            <template v-if="mergeRequest.state === 'closed'">
              <span class="merge-request-state">
                <i class="fa fa-ban"></i>
                {{ mergeRequest.state.toUpperCase() }}
              </span>
            </template>
            <template v-else>
              <span class="merge-request-branch" v-if="mergeRequest.branch">
                <i class= "fa fa-code-fork"></i>
                <a :href="mergeRequest.branch.url">{{ mergeRequest.branch.name }}</a>
              </span>
            </template>
          </div>
          <div class="item-time">
            <total-time :time="mergeRequest.totalTime"></total-time>
          </div>
        </li>
      </ul>
    </div>
  `,
});
