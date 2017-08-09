require 'spec_helper'

describe Banzai::Filter::RelativeLinkFilter do
  def filter(doc, contexts = {})
    contexts.reverse_merge!({
      commit:         commit,
      project:        project,
      project_wiki:   project_wiki,
      ref:            ref,
      requested_path: requested_path
    })

    described_class.call(doc, contexts)
  end

  def image(path)
    %(<img src="#{path}" />)
  end

  def video(path)
    %(<video src="#{path}"></video>)
  end

  def link(path)
    %(<a href="#{path}">#{path}</a>)
  end

  let(:project)        { create(:project, :repository) }
  let(:project_path)   { project.full_path }
  let(:ref)            { 'markdown' }
  let(:commit)         { project.commit(ref) }
  let(:project_wiki)   { nil }
  let(:requested_path) { '/' }

  shared_examples :preserve_unchanged do
    it 'does not modify any relative URL in anchor' do
      doc = filter(link('README.md'))
      expect(doc.at_css('a')['href']).to eq 'README.md'
    end

    it 'does not modify any relative URL in image' do
      doc = filter(image('files/images/logo-black.png'))
      expect(doc.at_css('img')['src']).to eq 'files/images/logo-black.png'
    end

    it 'does not modify any relative URL in video' do
      doc = filter(video('files/videos/intro.mp4'), commit: project.commit('video'), ref: 'video')

      expect(doc.at_css('video')['src']).to eq 'files/videos/intro.mp4'
    end
  end

  context 'with a project_wiki' do
    let(:project_wiki) { double('ProjectWiki') }
    include_examples :preserve_unchanged
  end

  context 'without a repository' do
    let(:project) { create(:project) }
    include_examples :preserve_unchanged
  end

  context 'with an empty repository' do
    let(:project) { create(:project_empty_repo) }
    include_examples :preserve_unchanged
  end

  it 'does not raise an exception on invalid URIs' do
    act = link("://foo")
    expect { filter(act) }.not_to raise_error
  end

  it 'ignores ref if commit is passed' do
    doc = filter(link('non/existent.file'), commit: project.commit('empty-branch') )
    expect(doc.at_css('a')['href'])
      .to eq "/#{project_path}/#{ref}/non/existent.file" # non-existent files have no leading blob/raw/tree
  end

  shared_examples :valid_repository do
    it 'rebuilds absolute URL for a file in the repo' do
      doc = filter(link('/doc/api/README.md'))
      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/blob/#{ref}/doc/api/README.md"
    end

    it 'ignores absolute URLs with two leading slashes' do
      doc = filter(link('//doc/api/README.md'))
      expect(doc.at_css('a')['href']).to eq '//doc/api/README.md'
    end

    it 'rebuilds relative URL for a file in the repo' do
      doc = filter(link('doc/api/README.md'))
      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/blob/#{ref}/doc/api/README.md"
    end

    it 'rebuilds relative URL for a file in the repo with leading ./' do
      doc = filter(link('./doc/api/README.md'))
      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/blob/#{ref}/doc/api/README.md"
    end

    it 'rebuilds relative URL for a file in the repo up one directory' do
      relative_link = link('../api/README.md')
      doc = filter(relative_link, requested_path: 'doc/update/7.14-to-8.0.md')

      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/blob/#{ref}/doc/api/README.md"
    end

    it 'rebuilds relative URL for a file in the repo up multiple directories' do
      relative_link = link('../../../api/README.md')
      doc = filter(relative_link, requested_path: 'doc/foo/bar/baz/README.md')

      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/blob/#{ref}/doc/api/README.md"
    end

    it 'rebuilds relative URL for a file in the repository root' do
      relative_link = link('../README.md')
      doc = filter(relative_link, requested_path: 'doc/some-file.md')

      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/blob/#{ref}/README.md"
    end

    it 'rebuilds relative URL for a file in the repo with an anchor' do
      doc = filter(link('README.md#section'))
      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/blob/#{ref}/README.md#section"
    end

    it 'rebuilds relative URL for a directory in the repo' do
      doc = filter(link('doc/api/'))
      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/tree/#{ref}/doc/api"
    end

    it 'rebuilds relative URL for an image in the repo' do
      doc = filter(image('files/images/logo-black.png'))

      expect(doc.at_css('img')['src'])
        .to eq "/#{project_path}/raw/#{ref}/files/images/logo-black.png"
    end

    it 'rebuilds relative URL for link to an image in the repo' do
      doc = filter(link('files/images/logo-black.png'))

      expect(doc.at_css('a')['href'])
        .to eq "/#{project_path}/raw/#{ref}/files/images/logo-black.png"
    end

    it 'rebuilds relative URL for a video in the repo' do
      doc = filter(video('files/videos/intro.mp4'), commit: project.commit('video'), ref: 'video')

      expect(doc.at_css('video')['src'])
        .to eq "/#{project_path}/raw/video/files/videos/intro.mp4"
    end

    it 'does not modify relative URL with an anchor only' do
      doc = filter(link('#section-1'))
      expect(doc.at_css('a')['href']).to eq '#section-1'
    end

    it 'does not modify absolute URL' do
      doc = filter(link('http://example.com'))
      expect(doc.at_css('a')['href']).to eq 'http://example.com'
    end

    it 'supports Unicode filenames' do
      path = 'files/images/한글.png'
      escaped = Addressable::URI.escape(path)

      # Stub this method so the file doesn't actually need to be in the repo
      allow_any_instance_of(described_class).to receive(:uri_type).and_return(:raw)

      doc = filter(image(escaped))
      expect(doc.at_css('img')['src']).to eq "/#{project_path}/raw/#{Addressable::URI.escape(ref)}/#{escaped}"
    end

    context 'when requested path is a file in the repo' do
      let(:requested_path) { 'doc/api/README.md' }
      it 'rebuilds URL relative to the containing directory' do
        doc = filter(link('users.md'))
        expect(doc.at_css('a')['href']).to eq "/#{project_path}/blob/#{Addressable::URI.escape(ref)}/doc/api/users.md"
      end
    end

    context 'when requested path is a directory in the repo' do
      let(:requested_path) { 'doc/api/' }
      it 'rebuilds URL relative to the directory' do
        doc = filter(link('users.md'))
        expect(doc.at_css('a')['href']).to eq "/#{project_path}/blob/#{Addressable::URI.escape(ref)}/doc/api/users.md"
      end
    end

    context 'when ref name contains percent sign' do
      let(:ref) { '100%branch' }
      let(:commit) { project.commit('1b12f15a11fc6e62177bef08f47bc7b5ce50b141') }
      let(:requested_path) { 'foo/bar/' }
      it 'correctly escapes the ref' do
        doc = filter(link('.gitkeep'))
        expect(doc.at_css('a')['href']).to eq "/#{project_path}/blob/#{Addressable::URI.escape(ref)}/foo/bar/.gitkeep"
      end
    end

    context 'when requested path is a directory with space in the repo' do
      let(:ref) { 'master' }
      let(:commit) { project.commit('38008cb17ce1466d8fec2dfa6f6ab8dcfe5cf49e') }
      let(:requested_path) { 'with space/' }
      it 'does not escape the space twice' do
        doc = filter(link('README.md'))
        expect(doc.at_css('a')['href']).to eq "/#{project_path}/blob/#{Addressable::URI.escape(ref)}/with%20space/README.md"
      end
    end
  end

  context 'with a valid commit' do
    include_examples :valid_repository
  end

  context 'with a valid ref' do
    let(:commit) { nil } # force filter to use ref instead of commit
    include_examples :valid_repository
  end
end
