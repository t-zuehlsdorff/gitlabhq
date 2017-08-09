import statusIcon from '../mr_widget_status_icon';

export default {
  name: 'MRWidgetPipelineBlocked',
  components: {
    statusIcon,
  },
  template: `
    <div class="mr-widget-body media">
      <status-icon status="failed" showDisabledButton />
      <div class="media-body space-children">
        <span class="bold">
          The pipeline for this merge request failed. Please retry the job or push a new commit to fix the failure
        </span>
      </div>
    </div>
  `,
};
