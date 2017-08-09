import Vue from 'vue';
import repoPrevDirectory from '~/repo/components/repo_prev_directory.vue';

describe('RepoPrevDirectory', () => {
  function createComponent(propsData) {
    const RepoPrevDirectory = Vue.extend(repoPrevDirectory);

    return new RepoPrevDirectory({
      propsData,
    }).$mount();
  }

  it('renders a prev dir link', () => {
    const prevUrl = 'prevUrl';
    const vm = createComponent({
      prevUrl,
    });
    const link = vm.$el.querySelector('a');

    spyOn(vm, 'linkClicked');

    expect(link.href).toMatch(`/${prevUrl}`);
    expect(link.textContent).toEqual('..');

    link.click();

    expect(vm.linkClicked).toHaveBeenCalledWith(prevUrl);
  });

  describe('methods', () => {
    describe('linkClicked', () => {
      const vm = jasmine.createSpyObj('vm', ['$emit']);

      it('$emits linkclicked with file obj', () => {
        const file = {};

        repoPrevDirectory.methods.linkClicked.call(vm, file);

        expect(vm.$emit).toHaveBeenCalledWith('linkclicked', file);
      });
    });
  });
});
