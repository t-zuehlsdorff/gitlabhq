require 'spec_helper'
require 'stringio'

describe Gitlab::Shell do
  let(:project) { double('Project', id: 7, path: 'diaspora') }
  let(:gitlab_shell) { described_class.new }
  let(:popen_vars) { { 'GIT_TERMINAL_PROMPT' => ENV['GIT_TERMINAL_PROMPT'] } }

  before do
    allow(Project).to receive(:find).and_return(project)
  end

  it { is_expected.to respond_to :add_key }
  it { is_expected.to respond_to :remove_key }
  it { is_expected.to respond_to :add_repository }
  it { is_expected.to respond_to :remove_repository }
  it { is_expected.to respond_to :fork_repository }
  it { is_expected.to respond_to :add_namespace }
  it { is_expected.to respond_to :rm_namespace }
  it { is_expected.to respond_to :mv_namespace }
  it { is_expected.to respond_to :exists? }

  it { expect(gitlab_shell.url_to_repo('diaspora')).to eq(Gitlab.config.gitlab_shell.ssh_path_prefix + "diaspora.git") }

  describe 'memoized secret_token' do
    let(:secret_file) { 'tmp/tests/.secret_shell_test' }
    let(:link_file) { 'tmp/tests/shell-secret-test/.gitlab_shell_secret' }

    before do
      allow(Gitlab.config.gitlab_shell).to receive(:secret_file).and_return(secret_file)
      allow(Gitlab.config.gitlab_shell).to receive(:path).and_return('tmp/tests/shell-secret-test')
      FileUtils.mkdir('tmp/tests/shell-secret-test')
      described_class.ensure_secret_token!
    end

    after do
      FileUtils.rm_rf('tmp/tests/shell-secret-test')
      FileUtils.rm_rf(secret_file)
    end

    it 'creates and links the secret token file' do
      secret_token = described_class.secret_token

      expect(File.exist?(secret_file)).to be(true)
      expect(File.read(secret_file).chomp).to eq(secret_token)
      expect(File.symlink?(link_file)).to be(true)
      expect(File.readlink(link_file)).to eq(secret_file)
    end
  end

  describe '#add_key' do
    it 'removes trailing garbage' do
      allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
      expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with(
        [:gitlab_shell_keys_path, 'add-key', 'key-123', 'ssh-rsa foobar']
      )

      gitlab_shell.add_key('key-123', 'ssh-rsa foobar trailing garbage')
    end
  end

  describe Gitlab::Shell::KeyAdder do
    describe '#add_key' do
      it 'removes trailing garbage' do
        io = spy(:io)
        adder = described_class.new(io)

        adder.add_key('key-42', "ssh-rsa foo bar\tbaz")

        expect(io).to have_received(:puts).with("key-42\tssh-rsa foo")
      end

      it 'handles multiple spaces in the key' do
        io = spy(:io)
        adder = described_class.new(io)

        adder.add_key('key-42', "ssh-rsa  foo")

        expect(io).to have_received(:puts).with("key-42\tssh-rsa foo")
      end

      it 'raises an exception if the key contains a tab' do
        expect do
          described_class.new(StringIO.new).add_key('key-42', "ssh-rsa\tfoobar")
        end.to raise_error(Gitlab::Shell::Error)
      end

      it 'raises an exception if the key contains a newline' do
        expect do
          described_class.new(StringIO.new).add_key('key-42', "ssh-rsa foobar\nssh-rsa pawned")
        end.to raise_error(Gitlab::Shell::Error)
      end
    end
  end

  describe 'projects commands' do
    let(:projects_path) { 'tmp/tests/shell-projects-test/bin/gitlab-projects' }

    before do
      allow(Gitlab.config.gitlab_shell).to receive(:path).and_return('tmp/tests/shell-projects-test')
      allow(Gitlab.config.gitlab_shell).to receive(:git_timeout).and_return(800)
    end

    describe '#add_repository' do
      it 'returns true when the command succeeds' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'add-project', 'current/storage', 'project/path.git'],
                nil, popen_vars).and_return([nil, 0])

        expect(gitlab_shell.add_repository('current/storage', 'project/path')).to be true
      end

      it 'returns false when the command fails' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'add-project', 'current/storage', 'project/path.git'],
                nil, popen_vars).and_return(["error", 1])

        expect(gitlab_shell.add_repository('current/storage', 'project/path')).to be false
      end
    end

    describe '#remove_repository' do
      it 'returns true when the command succeeds' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'rm-project', 'current/storage', 'project/path.git'],
                nil, popen_vars).and_return([nil, 0])

        expect(gitlab_shell.remove_repository('current/storage', 'project/path')).to be true
      end

      it 'returns false when the command fails' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'rm-project', 'current/storage', 'project/path.git'],
                nil, popen_vars).and_return(["error", 1])

        expect(gitlab_shell.remove_repository('current/storage', 'project/path')).to be false
      end
    end

    describe '#mv_repository' do
      it 'returns true when the command succeeds' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'mv-project', 'current/storage', 'project/path.git', 'project/newpath.git'],
                nil, popen_vars).and_return([nil, 0])

        expect(gitlab_shell.mv_repository('current/storage', 'project/path', 'project/newpath')).to be true
      end

      it 'returns false when the command fails' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'mv-project', 'current/storage', 'project/path.git', 'project/newpath.git'],
                nil, popen_vars).and_return(["error", 1])

        expect(gitlab_shell.mv_repository('current/storage', 'project/path', 'project/newpath')).to be false
      end
    end

    describe '#fork_repository' do
      it 'returns true when the command succeeds' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'fork-project', 'current/storage', 'project/path.git', 'new/storage', 'new-namespace'],
                nil, popen_vars).and_return([nil, 0])

        expect(gitlab_shell.fork_repository('current/storage', 'project/path', 'new/storage', 'new-namespace')).to be true
      end

      it 'return false when the command fails' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'fork-project', 'current/storage', 'project/path.git', 'new/storage', 'new-namespace'],
                nil, popen_vars).and_return(["error", 1])

        expect(gitlab_shell.fork_repository('current/storage', 'project/path', 'new/storage', 'new-namespace')).to be false
      end
    end

    describe '#fetch_remote' do
      def fetch_remote(ssh_auth = nil)
        gitlab_shell.fetch_remote('current/storage', 'project/path', 'new/storage', ssh_auth: ssh_auth)
      end

      def expect_popen(vars = {})
        popen_args = [
          projects_path,
          'fetch-remote',
          'current/storage',
          'project/path.git',
          'new/storage',
          Gitlab.config.gitlab_shell.git_timeout.to_s
        ]

        expect(Gitlab::Popen).to receive(:popen).with(popen_args, nil, popen_vars.merge(vars))
      end

      def build_ssh_auth(opts = {})
        defaults = {
          ssh_import?: true,
          ssh_key_auth?: false,
          ssh_known_hosts: nil,
          ssh_private_key: nil
        }

        double(:ssh_auth, defaults.merge(opts))
      end

      it 'returns true when the command succeeds' do
        expect_popen.and_return([nil, 0])

        expect(fetch_remote).to be_truthy
      end

      it 'raises an exception when the command fails' do
        expect_popen.and_return(["error", 1])

        expect { fetch_remote }.to raise_error(Gitlab::Shell::Error, "error")
      end

      context 'SSH auth' do
        it 'passes the SSH key if specified' do
          expect_popen('GITLAB_SHELL_SSH_KEY' => 'foo').and_return([nil, 0])

          ssh_auth = build_ssh_auth(ssh_key_auth?: true, ssh_private_key: 'foo')

          expect(fetch_remote(ssh_auth)).to be_truthy
        end

        it 'does not pass an empty SSH key' do
          expect_popen.and_return([nil, 0])

          ssh_auth = build_ssh_auth(ssh_key_auth: true, ssh_private_key: '')

          expect(fetch_remote(ssh_auth)).to be_truthy
        end

        it 'does not pass the key unless SSH key auth is to be used' do
          expect_popen.and_return([nil, 0])

          ssh_auth = build_ssh_auth(ssh_key_auth: false, ssh_private_key: 'foo')

          expect(fetch_remote(ssh_auth)).to be_truthy
        end

        it 'passes the known_hosts data if specified' do
          expect_popen('GITLAB_SHELL_KNOWN_HOSTS' => 'foo').and_return([nil, 0])

          ssh_auth = build_ssh_auth(ssh_known_hosts: 'foo')

          expect(fetch_remote(ssh_auth)).to be_truthy
        end

        it 'does not pass empty known_hosts data' do
          expect_popen.and_return([nil, 0])

          ssh_auth = build_ssh_auth(ssh_known_hosts: '')

          expect(fetch_remote(ssh_auth)).to be_truthy
        end

        it 'does not pass known_hosts data unless SSH is to be used' do
          expect_popen(popen_vars).and_return([nil, 0])

          ssh_auth = build_ssh_auth(ssh_import?: false, ssh_known_hosts: 'foo')

          expect(fetch_remote(ssh_auth)).to be_truthy
        end
      end
    end

    describe '#import_repository' do
      it 'returns true when the command succeeds' do
        expect(Gitlab::Popen).to receive(:popen)
          .with([projects_path, 'import-project', 'current/storage', 'project/path.git', 'https://gitlab.com/gitlab-org/gitlab-ce.git', "800"],
                nil, popen_vars).and_return([nil, 0])

        expect(gitlab_shell.import_repository('current/storage', 'project/path', 'https://gitlab.com/gitlab-org/gitlab-ce.git')).to be true
      end

      it 'raises an exception when the command fails' do
        expect(Gitlab::Popen).to receive(:popen)
        .with([projects_path, 'import-project', 'current/storage', 'project/path.git', 'https://gitlab.com/gitlab-org/gitlab-ce.git', "800"],
              nil, popen_vars).and_return(["error", 1])

        expect { gitlab_shell.import_repository('current/storage', 'project/path', 'https://gitlab.com/gitlab-org/gitlab-ce.git') }.to raise_error(Gitlab::Shell::Error, "error")
      end
    end
  end
end
