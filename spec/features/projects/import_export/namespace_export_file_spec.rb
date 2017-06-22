require 'spec_helper'

feature 'Import/Export - Namespace export file cleanup', feature: true, js: true do
  let(:export_path) { "#{Dir.tmpdir}/import_file_spec" }
  let(:config_hash) { YAML.load_file(Gitlab::ImportExport.config_file).deep_stringify_keys }

  let(:project) { create(:empty_project) }

  background do
    allow_any_instance_of(Gitlab::ImportExport).to receive(:storage_path).and_return(export_path)
  end

  after do
    FileUtils.rm_rf(export_path, secure: true)
  end

  context 'admin user' do
    before do
      gitlab_sign_in(:admin)
    end

    context 'moving the namespace' do
      scenario 'removes the export file' do
        setup_export_project

        old_export_path = project.export_path.dup

        expect(File).to exist(old_export_path)

        project.namespace.update(path: 'new_path')

        expect(File).not_to exist(old_export_path)
      end
    end

    context 'deleting the namespace' do
      scenario 'removes the export file' do
        setup_export_project

        old_export_path = project.export_path.dup

        expect(File).to exist(old_export_path)

        project.namespace.destroy

        expect(File).not_to exist(old_export_path)
      end
    end

    def setup_export_project
      visit edit_namespace_project_path(project.namespace, project)

      expect(page).to have_content('Export project')

      click_link 'Export project'

      visit edit_namespace_project_path(project.namespace, project)

      expect(page).to have_content('Download export')
    end
  end
end
