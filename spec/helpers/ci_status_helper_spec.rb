require 'spec_helper'

describe CiStatusHelper do
  include IconsHelper

  let(:success_commit) { double("Ci::Pipeline", status: 'success') }
  let(:failed_commit) { double("Ci::Pipeline", status: 'failed') }

  describe 'ci_icon_for_status' do
    it 'renders to correct svg on success' do
      expect(helper).to receive(:render).with('shared/icons/icon_status_success.svg', anything)
      helper.ci_icon_for_status(success_commit.status)
    end
    it 'renders the correct svg on failure' do
      expect(helper).to receive(:render).with('shared/icons/icon_status_failed.svg', anything)
      helper.ci_icon_for_status(failed_commit.status)
    end
  end

  describe "#pipeline_status_cache_key" do
    it "builds a cache key for pipeline status" do
      pipeline_status = Gitlab::Cache::Ci::ProjectPipelineStatus.new(
        build(:project),
        sha: "123abc",
        status: "success"
      )
      expect(helper.pipeline_status_cache_key(pipeline_status)).to eq("pipeline-status/123abc-success")
    end
  end
end
