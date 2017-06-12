module SharedMarkdown
  include Spinach::DSL

  def header_should_have_correct_id_and_link(level, text, id, parent = ".wiki")
    node = find("#{parent} h#{level} a#user-content-#{id}")
    expect(node[:href]).to end_with "##{id}"

    # Work around a weird Capybara behavior where calling `parent` on a node
    # returns the whole document, not the node's actual parent element
    expect(find(:xpath, "#{node.path}/..").text).to eq text
  end

  step 'Header "Description header" should have correct id and link' do
    header_should_have_correct_id_and_link(1, 'Description header', 'description-header')
  end

  step 'I should not see the Markdown preview' do
    expect(find('.gfm-form .js-md-preview')).not_to be_visible
  end

  step 'The Markdown preview tab should say there is nothing to do' do
    page.within('.gfm-form') do
      find('.js-md-preview-button').click
      expect(find('.js-md-preview')).to have_content('Nothing to preview.')
    end
  end

  step 'I should not see the Markdown text field' do
    expect(find('.gfm-form textarea')).not_to be_visible
  end

  step 'I should see the Markdown write tab' do
    expect(first('.gfm-form')).to have_link('Write', visible: true)
  end

  step 'I should see the Markdown preview' do
    expect(find('.gfm-form')).to have_css('.js-md-preview', visible: true)
  end

  step 'The Markdown preview tab should display rendered Markdown' do
    page.within('.gfm-form') do
      find('.js-md-preview-button').click
      expect(find('.js-md-preview')).to have_css('gl-emoji', visible: true)
    end
  end

  step 'I write a description like ":+1: Nice"' do
    find('.gfm-form').fill_in 'Description', with: ':+1: Nice'
  end

  step 'I preview a description text like "Bug fixed :smile:"' do
    page.within(first('.gfm-form')) do
      fill_in 'Description', with: 'Bug fixed :smile:'
      click_link 'Preview'
    end
  end

  step 'I haven\'t written any description text' do
    find('.gfm-form').fill_in 'Description', with: ''
  end
end
