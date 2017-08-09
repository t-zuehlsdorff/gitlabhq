import statusIcon from '../mr_widget_status_icon';

export default {
  name: 'MRWidgetUnresolvedDiscussions',
  props: {
    mr: { type: Object, required: true },
  },
  components: {
    statusIcon,
  },
  template: `
    <div class="mr-widget-body media">
      <status-icon status="failed" showDisabledButton />
      <div class="media-body space-children">
        <span class="bold">
          There are unresolved discussions. Please resolve these discussions
        </span>
        <a
          v-if="mr.createIssueToResolveDiscussionsPath"
          :href="mr.createIssueToResolveDiscussionsPath"
          class="btn btn-default btn-xs js-create-issue">
          Create an issue to resolve them later
        </a>
      </div>
    </div>
  `,
};
