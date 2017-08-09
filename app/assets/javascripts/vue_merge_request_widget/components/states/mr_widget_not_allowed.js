import statusIcon from '../mr_widget_status_icon';

export default {
  name: 'MRWidgetNotAllowed',
  components: {
    statusIcon,
  },
  template: `
    <div class="mr-widget-body media">
      <status-icon status="success" showDisabledButton />
      <div class="media-body space-children">
        <span class="bold">
          Ready to be merged automatically.
          Ask someone with write access to this repository to merge this request
        </span>
      </div>
    </div>
  `,
};
