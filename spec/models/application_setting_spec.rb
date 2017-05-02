require 'spec_helper'

describe ApplicationSetting, models: true do
  let(:setting) { ApplicationSetting.create_from_defaults }

  it { expect(setting).to be_valid }
  it { expect(setting.uuid).to be_present }

  describe 'validations' do
    let(:http)  { 'http://example.com' }
    let(:https) { 'https://example.com' }
    let(:ftp)   { 'ftp://example.com' }

    it { is_expected.to allow_value(nil).for(:home_page_url) }
    it { is_expected.to allow_value(http).for(:home_page_url) }
    it { is_expected.to allow_value(https).for(:home_page_url) }
    it { is_expected.not_to allow_value(ftp).for(:home_page_url) }

    it { is_expected.to allow_value(nil).for(:after_sign_out_path) }
    it { is_expected.to allow_value(http).for(:after_sign_out_path) }
    it { is_expected.to allow_value(https).for(:after_sign_out_path) }
    it { is_expected.not_to allow_value(ftp).for(:after_sign_out_path) }

    describe 'disabled_oauth_sign_in_sources validations' do
      before do
        allow(Devise).to receive(:omniauth_providers).and_return([:github])
      end

      it { is_expected.to allow_value(['github']).for(:disabled_oauth_sign_in_sources) }
      it { is_expected.not_to allow_value(['test']).for(:disabled_oauth_sign_in_sources) }
    end

    describe 'default_artifacts_expire_in' do
      it 'sets an error if it cannot parse' do
        setting.update(default_artifacts_expire_in: 'a')

        expect_invalid
      end

      it 'sets an error if it is blank' do
        setting.update(default_artifacts_expire_in: ' ')

        expect_invalid
      end

      it 'sets the value if it is valid' do
        setting.update(default_artifacts_expire_in: '30 days')

        expect(setting).to be_valid
        expect(setting.default_artifacts_expire_in).to eq('30 days')
      end

      it 'sets the value if it is 0' do
        setting.update(default_artifacts_expire_in: '0')

        expect(setting).to be_valid
        expect(setting.default_artifacts_expire_in).to eq('0')
      end

      def expect_invalid
        expect(setting).to be_invalid
        expect(setting.errors.messages)
          .to have_key(:default_artifacts_expire_in)
      end
    end

    it { is_expected.to validate_presence_of(:max_attachment_size) }

    it do
      is_expected.to validate_numericality_of(:max_attachment_size)
        .only_integer
        .is_greater_than(0)
    end

    it_behaves_like 'an object with email-formated attributes', :admin_notification_email do
      subject { setting }
    end

    # Upgraded databases will have this sort of content
    context 'repository_storages is a String, not an Array' do
      before { setting.__send__(:raw_write_attribute, :repository_storages, 'default') }

      it { expect(setting.repository_storages_before_type_cast).to eq('default') }
      it { expect(setting.repository_storages).to eq(['default']) }
    end

    context 'repository storages' do
      before do
        storages = {
          'custom1' => 'tmp/tests/custom_repositories_1',
          'custom2' => 'tmp/tests/custom_repositories_2',
          'custom3' => 'tmp/tests/custom_repositories_3',

        }
        allow(Gitlab.config.repositories).to receive(:storages).and_return(storages)
      end

      describe 'inclusion' do
        it { is_expected.to allow_value('custom1').for(:repository_storages) }
        it { is_expected.to allow_value(%w(custom2 custom3)).for(:repository_storages) }
        it { is_expected.not_to allow_value('alternative').for(:repository_storages) }
        it { is_expected.not_to allow_value(%w(alternative custom1)).for(:repository_storages) }
      end

      describe 'presence' do
        it { is_expected.not_to allow_value([]).for(:repository_storages) }
        it { is_expected.not_to allow_value("").for(:repository_storages) }
        it { is_expected.not_to allow_value(nil).for(:repository_storages) }
      end

      describe '.pick_repository_storage' do
        it 'uses Array#sample to pick a random storage' do
          array = double('array', sample: 'random')
          expect(setting).to receive(:repository_storages).and_return(array)

          expect(setting.pick_repository_storage).to eq('random')
        end

        describe '#repository_storage' do
          it 'returns the first storage' do
            setting.repository_storages = %w(good bad)

            expect(setting.repository_storage).to eq('good')
          end
        end

        describe '#repository_storage=' do
          it 'overwrites repository_storages' do
            setting.repository_storage = 'overwritten'

            expect(setting.repository_storages).to eq(['overwritten'])
          end
        end
      end
    end

    context 'housekeeping settings' do
      it { is_expected.not_to allow_value(0).for(:housekeeping_incremental_repack_period) }

      it 'wants the full repack period to be longer than the incremental repack period' do
        subject.housekeeping_incremental_repack_period = 2
        subject.housekeeping_full_repack_period = 1

        expect(subject).not_to be_valid
      end

      it 'wants the gc period to be longer than the full repack period' do
        subject.housekeeping_full_repack_period = 2
        subject.housekeeping_gc_period = 1

        expect(subject).not_to be_valid
      end
    end
  end

  context 'restricted signup domains' do
    it 'sets single domain' do
      setting.domain_whitelist_raw = 'example.com'
      expect(setting.domain_whitelist).to eq(['example.com'])
    end

    it 'sets multiple domains with spaces' do
      setting.domain_whitelist_raw = 'example.com *.example.com'
      expect(setting.domain_whitelist).to eq(['example.com', '*.example.com'])
    end

    it 'sets multiple domains with newlines and a space' do
      setting.domain_whitelist_raw = "example.com\n *.example.com"
      expect(setting.domain_whitelist).to eq(['example.com', '*.example.com'])
    end

    it 'sets multiple domains with commas' do
      setting.domain_whitelist_raw = "example.com, *.example.com"
      expect(setting.domain_whitelist).to eq(['example.com', '*.example.com'])
    end
  end

  context 'blacklisted signup domains' do
    it 'sets single domain' do
      setting.domain_blacklist_raw = 'example.com'
      expect(setting.domain_blacklist).to contain_exactly('example.com')
    end

    it 'sets multiple domains with spaces' do
      setting.domain_blacklist_raw = 'example.com *.example.com'
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with newlines and a space' do
      setting.domain_blacklist_raw = "example.com\n *.example.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with commas' do
      setting.domain_blacklist_raw = "example.com, *.example.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with semicolon' do
      setting.domain_blacklist_raw = "example.com; *.example.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with mixture of everything' do
      setting.domain_blacklist_raw = "example.com; *.example.com\n test.com\sblock.com   yes.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com', 'test.com', 'block.com', 'yes.com')
    end

    it 'sets multiple domain with file' do
      setting.domain_blacklist_file = File.open(Rails.root.join('spec/fixtures/', 'domain_blacklist.txt'))
      expect(setting.domain_blacklist).to contain_exactly('example.com', 'test.com', 'foo.bar')
    end
  end
end
