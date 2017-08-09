require 'spec_helper'

describe 'Gitlab::Popen' do
  let(:path) { Rails.root.join('tmp').to_s }

  before do
    @klass = Class.new(Object)
    @klass.send(:include, Gitlab::Popen)
  end

  context 'zero status' do
    before do
      @output, @status = @klass.new.popen(%w(ls), path)
    end

    it { expect(@status).to be_zero }
    it { expect(@output).to include('cache') }
  end

  context 'non-zero status' do
    before do
      @output, @status = @klass.new.popen(%w(cat NOTHING), path)
    end

    it { expect(@status).to eq(1) }
    it { expect(@output).to include('No such file or directory') }
  end

  context 'unsafe string command' do
    it 'raises an error when it gets called with a string argument' do
      expect { @klass.new.popen('ls', path) }.to raise_error(RuntimeError)
    end
  end

  context 'with custom options' do
    let(:vars) { { 'foobar' => 123, 'PWD' => path } }
    let(:options) { { chdir: path } }

    it 'calls popen3 with the provided environment variables' do
      expect(Open3).to receive(:popen3).with(vars, 'ls', options)

      @output, @status = @klass.new.popen(%w(ls), path, { 'foobar' => 123 })
    end
  end

  context 'without a directory argument' do
    before do
      @output, @status = @klass.new.popen(%w(ls))
    end

    it { expect(@status).to be_zero }
    it { expect(@output).to include('spec') }
  end

  context 'use stdin' do
    before do
      @output, @status = @klass.new.popen(%w[cat]) { |stdin| stdin.write 'hello' }
    end

    it { expect(@status).to be_zero }
    it { expect(@output).to eq('hello') }
  end
end
