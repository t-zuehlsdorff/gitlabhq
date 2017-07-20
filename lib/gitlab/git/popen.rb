# Gitaly note: JV: no RPC's here.

require 'open3'

module Gitlab
  module Git
    module Popen
      def popen(cmd, path)
        unless cmd.is_a?(Array)
          raise "System commands must be given as an array of strings"
        end

        vars = { "PWD" => path }
        options = { chdir: path }

        @cmd_output = ""
        @cmd_status = 0
        Open3.popen3(vars, *cmd, options) do |stdin, stdout, stderr, wait_thr|
          @cmd_output << stdout.read
          @cmd_output << stderr.read
          @cmd_status = wait_thr.value.exitstatus
        end

        [@cmd_output, @cmd_status]
      end
    end
  end
end
