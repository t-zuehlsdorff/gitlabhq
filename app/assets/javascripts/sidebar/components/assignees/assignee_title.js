export default {
  name: 'AssigneeTitle',
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    numberOfAssignees: {
      type: Number,
      required: true,
    },
    editable: {
      type: Boolean,
      required: true,
    },
    showToggle: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    assigneeTitle() {
      const assignees = this.numberOfAssignees;
      return assignees > 1 ? `${assignees} Assignees` : 'Assignee';
    },
  },
  template: `
    <div class="title hide-collapsed">
      {{assigneeTitle}}
      <i
        v-if="loading"
        aria-hidden="true"
        class="fa fa-spinner fa-spin block-loading"
      />
      <a
        v-if="editable"
        class="edit-link pull-right"
        href="#"
      >
        Edit
      </a>
      <a
        v-if="showToggle"
        aria-label="Toggle sidebar"
        class="gutter-toggle pull-right js-sidebar-toggle"
        href="#"
        role="button"
      >
        <i
          aria-hidden="true"
          data-hidden="true"
          class="fa fa-angle-double-right"
        />
      </a>
    </div>
  `,
};
