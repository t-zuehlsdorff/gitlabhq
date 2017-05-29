require 'spec_helper'

describe 'GFM autocomplete loading', feature: true, js: true do
  let(:project)   { create(:project) }

  before do
    login_as :admin

    visit namespace_project_path(project.namespace, project)
  end

  it 'does not load on project#show' do
    expect(evaluate_script('gl.GfmAutoComplete')).to eq(nil)
  end

  it 'loads on new issue page' do
    visit new_namespace_project_issue_path(project.namespace, project)

    expect(evaluate_script('gl.GfmAutoComplete.dataSources')).not_to eq({})
  end
end
