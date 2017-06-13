import Vue from 'vue';
import sidebarDetailRow from '~/jobs/components/sidebar_detail_row.vue';

describe('Sidebar detail row', () => {
  let SidebarDetailRow;
  let vm;

  beforeEach(() => {
    SidebarDetailRow = Vue.extend(sidebarDetailRow);
  });

  afterEach(() => {
    vm.$destroy();
  });

  it('should render no title', () => {
    vm = new SidebarDetailRow({
      propsData: {
        value: 'this is the value',
      },
    }).$mount();

    expect(vm.$el.textContent.replace(/\s+/g, ' ').trim()).toEqual('this is the value');
  });

  beforeEach(() => {
    vm = new SidebarDetailRow({
      propsData: {
        title: 'this is the title',
        value: 'this is the value',
      },
    }).$mount();
  });

  it('should render provided title and value', () => {
    expect(
      vm.$el.textContent.replace(/\s+/g, ' ').trim(),
    ).toEqual('this is the title: this is the value');
  });
});
