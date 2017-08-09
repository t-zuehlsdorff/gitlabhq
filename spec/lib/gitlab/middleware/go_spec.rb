require 'spec_helper'

describe Gitlab::Middleware::Go do
  let(:app) { double(:app) }
  let(:middleware) { described_class.new(app) }

  describe '#call' do
    describe 'when go-get=0' do
      it 'skips go-import generation' do
        env = { 'rack.input' => '',
                'QUERY_STRING' => 'go-get=0' }
        expect(app).to receive(:call).with(env).and_return('no-go')
        middleware.call(env)
      end
    end

    describe 'when go-get=1' do
      let(:current_user) { nil }

      context 'with simple 2-segment project path' do
        let!(:project) { create(:project, :private) }

        context 'with subpackages' do
          let(:path) { "#{project.full_path}/subpackage" }

          it 'returns the full project path' do
            expect_response_with_path(go, project.full_path)
          end
        end

        context 'without subpackages' do
          let(:path) { project.full_path }

          it 'returns the full project path' do
            expect_response_with_path(go, project.full_path)
          end
        end
      end

      context 'with a nested project path' do
        let(:group) { create(:group, :nested) }
        let!(:project) { create(:project, :public, namespace: group) }

        shared_examples 'a nested project' do
          context 'when the project is public' do
            it 'returns the full project path' do
              expect_response_with_path(go, project.full_path)
            end
          end

          context 'when the project is private' do
            before do
              project.update_attribute(:visibility_level, Project::PRIVATE)
            end

            context 'with access to the project' do
              let(:current_user) { project.creator }

              before do
                project.team.add_master(current_user)
              end

              it 'returns the full project path' do
                expect_response_with_path(go, project.full_path)
              end
            end

            context 'without access to the project' do
              it 'returns the 2-segment group path' do
                expect_response_with_path(go, group.full_path)
              end
            end
          end
        end

        context 'with subpackages' do
          let(:path) { "#{project.full_path}/subpackage" }

          it_behaves_like 'a nested project'
        end

        context 'without subpackages' do
          let(:path) { project.full_path }

          it_behaves_like 'a nested project'
        end
      end
    end

    def go
      env = {
        'rack.input' => '',
        'QUERY_STRING' => 'go-get=1',
        'PATH_INFO' => "/#{path}",
        'warden' => double(authenticate: current_user)
      }
      middleware.call(env)
    end

    def expect_response_with_path(response, path)
      expect(response[0]).to eq(200)
      expect(response[1]['Content-Type']).to eq('text/html')
      expected_body = "<!DOCTYPE html><html><head><meta content='#{Gitlab.config.gitlab.host}/#{path} git http://#{Gitlab.config.gitlab.host}/#{path}.git' name='go-import'></head></html>\n"
      expect(response[2].body).to eq([expected_body])
    end
  end
end
