import Vue from 'vue';
import headerComponent from '~/jobs/components/header.vue';

describe('Job details header', () => {
  let HeaderComponent;
  let vm;
  let props;

  beforeEach(() => {
    HeaderComponent = Vue.extend(headerComponent);

    const threeWeeksAgo = new Date();
    threeWeeksAgo.setDate(threeWeeksAgo.getDate() - 21);

    props = {
      job: {
        status: {
          group: 'failed',
          icon: 'ci-status-failed',
          label: 'failed',
          text: 'failed',
          details_path: 'path',
        },
        id: 123,
        created_at: threeWeeksAgo.toISOString(),
        user: {
          web_url: 'path',
          name: 'Foo',
          username: 'foobar',
          email: 'foo@bar.com',
          avatar_url: 'link',
        },
        retry_path: 'path',
        new_issue_path: 'path',
      },
      isLoading: false,
    };

    vm = new HeaderComponent({ propsData: props }).$mount();
  });

  afterEach(() => {
    vm.$destroy();
  });

  it('should render provided job information', () => {
    expect(
      vm.$el.querySelector('.header-main-content').textContent.replace(/\s+/g, ' ').trim(),
    ).toEqual('failed Job #123 triggered 3 weeks ago by Foo');
  });

  it('should render retry link', () => {
    expect(
      vm.$el.querySelector('.js-retry-button').getAttribute('href'),
    ).toEqual(props.job.retry_path);
  });

  it('should render new issue link', () => {
    expect(
      vm.$el.querySelector('.js-new-issue').getAttribute('href'),
    ).toEqual(props.job.new_issue_path);
  });
});
