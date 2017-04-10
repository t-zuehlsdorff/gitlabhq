require 'rake_helper'

describe 'gitlab:gitaly namespace rake task' do
  before :all do
    Rake.application.rake_require 'tasks/gitlab/gitaly'
  end

  describe 'install' do
    let(:repo) { 'https://gitlab.com/gitlab-org/gitaly.git' }
    let(:clone_path) { Rails.root.join('tmp/tests/gitaly').to_s }
    let(:tag) { "v#{File.read(Rails.root.join(Gitlab::GitalyClient::SERVER_VERSION_FILE)).chomp}" }

    context 'no dir given' do
      it 'aborts and display a help message' do
        # avoid writing task output to spec progress
        allow($stderr).to receive :write
        expect { run_rake_task('gitlab:gitaly:install') }.to raise_error /Please specify the directory where you want to install gitaly/
      end
    end

    context 'when an underlying Git command fail' do
      it 'aborts and display a help message' do
        expect_any_instance_of(Object).
          to receive(:checkout_or_clone_tag).and_raise 'Git error'

        expect { run_rake_task('gitlab:gitaly:install', clone_path) }.to raise_error 'Git error'
      end
    end

    describe 'checkout or clone' do
      before do
        expect(Dir).to receive(:chdir).with(clone_path)
      end

      it 'calls checkout_or_clone_tag with the right arguments' do
        expect_any_instance_of(Object).
          to receive(:checkout_or_clone_tag).with(tag: tag, repo: repo, target_dir: clone_path)

        run_rake_task('gitlab:gitaly:install', clone_path)
      end
    end

    describe 'gmake/make' do
      before do
        FileUtils.mkdir_p(clone_path)
        expect(Dir).to receive(:chdir).with(clone_path).and_call_original
      end

      context 'gmake is available' do
        before do
          expect_any_instance_of(Object).to receive(:checkout_or_clone_tag)
          allow_any_instance_of(Object).to receive(:run_command!).with(['gmake']).and_return(true)
        end

        it 'calls gmake in the gitaly directory' do
          expect(Gitlab::Popen).to receive(:popen).with(%w[which gmake]).and_return(['/usr/bin/gmake', 0])
          expect_any_instance_of(Object).to receive(:run_command!).with(['gmake']).and_return(true)

          run_rake_task('gitlab:gitaly:install', clone_path)
        end
      end

      context 'gmake is not available' do
        before do
          expect_any_instance_of(Object).to receive(:checkout_or_clone_tag)
          allow_any_instance_of(Object).to receive(:run_command!).with(['make']).and_return(true)
        end

        it 'calls make in the gitaly directory' do
          expect(Gitlab::Popen).to receive(:popen).with(%w[which gmake]).and_return(['', 42])
          expect_any_instance_of(Object).to receive(:run_command!).with(['make']).and_return(true)

          run_rake_task('gitlab:gitaly:install', clone_path)
        end
      end
    end
  end

  describe 'storage_config' do
    it 'prints storage configuration in a TOML format' do
      config = {
        'default' => { 'path' => '/path/to/default' },
        'nfs_01' => { 'path' => '/path/to/nfs_01' },
      }
      allow(Gitlab.config.repositories).to receive(:storages).and_return(config)

      orig_stdout = $stdout
      $stdout = StringIO.new

      header = ''
      Timecop.freeze do
        header = <<~TOML
          # Gitaly storage configuration generated from #{Gitlab.config.source} on #{Time.current.to_s(:long)}
          # This is in TOML format suitable for use in Gitaly's config.toml file.
        TOML
        run_rake_task('gitlab:gitaly:storage_config')
      end

      output = $stdout.string
      $stdout = orig_stdout

      expect(output).to include(header)

      parsed_output = TOML.parse(output)
      config.each do |name, params|
        expect(parsed_output['storage']).to include({ 'name' => name, 'path' => params['path'] })
      end
    end
  end
end
