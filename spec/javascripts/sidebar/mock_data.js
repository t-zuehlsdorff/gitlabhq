/* eslint-disable quote-props*/

const sidebarMockData = {
  'GET': {
    '/gitlab-org/gitlab-shell/issues/5.json': {
      id: 45,
      iid: 5,
      author_id: 23,
      description: 'Nulla ullam commodi delectus adipisci quis sit.',
      lock_version: null,
      milestone_id: 21,
      position: 0,
      state: 'closed',
      title: 'Vel et nulla voluptatibus corporis dolor iste saepe laborum.',
      updated_by_id: 1,
      created_at: '2017-02-02T21: 49: 49.664Z',
      updated_at: '2017-05-03T22: 26: 03.760Z',
      deleted_at: null,
      time_estimate: 0,
      total_time_spent: 0,
      human_time_estimate: null,
      human_total_time_spent: null,
      branch_name: null,
      confidential: false,
      assignees: [
        {
          name: 'User 0',
          username: 'user0',
          id: 22,
          state: 'active',
          avatar_url: 'http: //www.gravatar.com/avatar/52e4ce24a915fb7e51e1ad3b57f4b00a?s=80\u0026d=identicon',
          web_url: 'http: //localhost:3001/user0',
        },
        {
          name: 'Marguerite Bartell',
          username: 'tajuana',
          id: 18,
          state: 'active',
          avatar_url: 'http: //www.gravatar.com/avatar/4852a41fb41616bf8f140d3701673f53?s=80\u0026d=identicon',
          web_url: 'http: //localhost:3001/tajuana',
        },
        {
          name: 'Laureen Ritchie',
          username: 'michaele.will',
          id: 16,
          state: 'active',
          avatar_url: 'http: //www.gravatar.com/avatar/e301827eb03be955c9c172cb9a8e4e8a?s=80\u0026d=identicon',
          web_url: 'http: //localhost:3001/michaele.will',
        },
      ],
      due_date: null,
      moved_to_id: null,
      project_id: 4,
      weight: null,
      milestone: {
        id: 21,
        iid: 1,
        project_id: 4,
        title: 'v0.0',
        description: 'Molestiae commodi laboriosam odio sunt eaque reprehenderit.',
        state: 'active',
        created_at: '2017-02-02T21: 49: 30.530Z',
        updated_at: '2017-02-02T21: 49: 30.530Z',
        due_date: null,
        start_date: null,
      },
      labels: [],
    },
  },
  'PUT': {
    '/gitlab-org/gitlab-shell/issues/5.json': {
      data: {},
    },
  },
};

export default {
  mediator: {
    endpoint: '/gitlab-org/gitlab-shell/issues/5.json',
    editable: true,
    currentUser: {
      id: 1,
      name: 'Administrator',
      username: 'root',
      avatar_url: 'http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
    },
    rootPath: '/',
  },
  time: {
    time_estimate: 3600,
    total_time_spent: 0,
    human_time_estimate: '1h',
    human_total_time_spent: null,
  },
  user: {
    avatar: 'http://gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
    id: 1,
    name: 'Administrator',
    username: 'root',
  },

  sidebarMockInterceptor(request, next) {
    const body = sidebarMockData[request.method.toUpperCase()][request.url];

    next(request.respondWith(JSON.stringify(body), {
      status: 200,
    }));
  },
};
