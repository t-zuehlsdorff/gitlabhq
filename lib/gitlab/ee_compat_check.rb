# rubocop: disable Rails/Output
module Gitlab
  # Checks if a set of migrations requires downtime or not.
  class EeCompatCheck
    CE_REPO = 'https://gitlab.com/gitlab-org/gitlab-ce.git'.freeze
    EE_REPO = 'https://gitlab.com/gitlab-org/gitlab-ee.git'.freeze
    CHECK_DIR = Rails.root.join('ee_compat_check')
    IGNORED_FILES_REGEX = /(VERSION|CHANGELOG\.md:\d+)/.freeze
    PLEASE_READ_THIS_BANNER = %Q{
      ============================================================
      ===================== PLEASE READ THIS =====================
      ============================================================
    }.freeze
    THANKS_FOR_READING_BANNER = %Q{
      ============================================================
      ==================== THANKS FOR READING ====================
      ============================================================\n
    }.freeze

    attr_reader :ee_repo_dir, :patches_dir, :ce_repo, :ce_branch, :ee_branch_found
    attr_reader :failed_files

    def initialize(branch:, ce_repo: CE_REPO)
      @ee_repo_dir = CHECK_DIR.join('ee-repo')
      @patches_dir = CHECK_DIR.join('patches')
      @ce_branch = branch
      @ce_repo = ce_repo
    end

    def check
      ensure_patches_dir
      generate_patch(ce_branch, ce_patch_full_path)

      ensure_ee_repo
      Dir.chdir(ee_repo_dir) do
        step("In the #{ee_repo_dir} directory")

        status = catch(:halt_check) do
          ce_branch_compat_check!
          delete_ee_branches_locally!
          ee_branch_presence_check!
          ee_branch_compat_check!
        end

        delete_ee_branches_locally!

        if status.nil?
          true
        else
          false
        end
      end
    end

    private

    def ensure_ee_repo
      if Dir.exist?(ee_repo_dir)
        step("#{ee_repo_dir} already exists")
      else
        step(
          "Cloning #{EE_REPO} into #{ee_repo_dir}",
          %W[git clone --branch master --single-branch --depth=200 #{EE_REPO} #{ee_repo_dir}]
        )
      end
    end

    def ensure_patches_dir
      FileUtils.mkdir_p(patches_dir)
    end

    def generate_patch(branch, patch_path)
      FileUtils.rm(patch_path, force: true)

      find_merge_base_with_master(branch: branch)

      step(
        "Generating the patch against origin/master in #{patch_path}",
        %w[git diff --binary origin/master...HEAD]
      ) do |output, status|
        throw(:halt_check, :ko) unless status.zero?

        File.write(patch_path, output)

        throw(:halt_check, :ko) unless File.exist?(patch_path)
      end
    end

    def ce_branch_compat_check!
      if check_patch(ce_patch_full_path).zero?
        puts applies_cleanly_msg(ce_branch)
        throw(:halt_check)
      end
    end

    def ee_branch_presence_check!
      _, status = step("Fetching origin/#{ee_branch_prefix}", %W[git fetch origin #{ee_branch_prefix}])

      if status.zero?
        @ee_branch_found = ee_branch_prefix
      else
        _, status = step("Fetching origin/#{ee_branch_suffix}", %W[git fetch origin #{ee_branch_suffix}])
      end

      if status.zero?
        @ee_branch_found = ee_branch_suffix
      else
        puts
        puts ce_branch_doesnt_apply_cleanly_and_no_ee_branch_msg

        throw(:halt_check, :ko)
      end
    end

    def ee_branch_compat_check!
      step("Checking out origin/#{ee_branch_found}", %W[git checkout -b #{ee_branch_found} FETCH_HEAD])

      generate_patch(ee_branch_found, ee_patch_full_path)

      unless check_patch(ee_patch_full_path).zero?
        puts
        puts ee_branch_doesnt_apply_cleanly_msg

        throw(:halt_check, :ko)
      end

      puts
      puts applies_cleanly_msg(ee_branch_found)
    end

    def check_patch(patch_path)
      step("Checking out master", %w[git checkout master])
      step("Resetting to latest master", %w[git reset --hard origin/master])
      step("Fetching CE/#{ce_branch}", %W[git fetch #{CE_REPO} #{ce_branch}])
      step(
        "Checking if #{patch_path} applies cleanly to EE/master",
        # Don't use --check here because it can result in a 0-exit status even
        # though the patch doesn't apply cleanly, e.g.:
        #   > git apply --check --3way foo.patch
        #   error: patch failed: lib/gitlab/ee_compat_check.rb:74
        #   Falling back to three-way merge...
        #   Applied patch to 'lib/gitlab/ee_compat_check.rb' with conflicts.
        #   > echo $?
        #   0
        %W[git apply --3way #{patch_path}]
      ) do |output, status|
        puts output
        unless status.zero?
          @failed_files = output.lines.reduce([]) do |memo, line|
            if line.start_with?('error: patch failed:')
              file = line.sub(/\Aerror: patch failed: /, '')
              memo << file unless file =~ IGNORED_FILES_REGEX
            end
            memo
          end

          status = 0 if failed_files.empty?
        end

        command(%w[git reset --hard])
        status
      end
    end

    def delete_ee_branches_locally!
      command(%w[git checkout master])
      command(%W[git branch --delete --force #{ee_branch_prefix}])
      command(%W[git branch --delete --force #{ee_branch_suffix}])
    end

    def merge_base_found?
      step(
        "Finding merge base with master",
        %w[git merge-base origin/master HEAD]
      ) do |output, status|
        if status.zero?
          puts "Merge base was found: #{output}"
          true
        end
      end
    end

    def find_merge_base_with_master(branch:)
      # Start with (Math.exp(3).to_i = 20) until (Math.exp(6).to_i = 403)
      # In total we go (20 + 54 + 148 + 403 = 625) commits deeper
      depth = 20
      success =
        (3..6).any? do |factor|
          depth += Math.exp(factor).to_i
          # Repository is initially cloned with a depth of 20 so we need to fetch
          # deeper in the case the branch has more than 20 commits on top of master
          fetch(branch: branch, depth: depth)
          fetch(branch: 'master', depth: depth)

          merge_base_found?
        end

      raise "\n#{branch} is too far behind master, please rebase it!\n" unless success
    end

    def fetch(branch:, depth:)
      step(
        "Fetching deeper...",
        %W[git fetch --depth=#{depth} --prune origin +refs/heads/#{branch}:refs/remotes/origin/#{branch}]
      ) do |output, status|
        raise "Fetch failed: #{output}" unless status.zero?
      end
    end

    def ce_patch_name
      @ce_patch_name ||= patch_name_from_branch(ce_branch)
    end

    def ce_patch_full_path
      @ce_patch_full_path ||= patches_dir.join(ce_patch_name)
    end

    def ee_branch_suffix
      @ee_branch_suffix ||= "#{ce_branch}-ee"
    end

    def ee_branch_prefix
      @ee_branch_prefix ||= "ee-#{ce_branch}"
    end

    def ee_patch_name
      @ee_patch_name ||= patch_name_from_branch(ee_branch_found)
    end

    def ee_patch_full_path
      @ee_patch_full_path ||= patches_dir.join(ee_patch_name)
    end

    def patch_name_from_branch(branch_name)
      branch_name.parameterize << '.patch'
    end

    def patch_url
      "https://gitlab.com/gitlab-org/gitlab-ce/-/jobs/#{ENV['CI_JOB_ID']}/artifacts/raw/ee_compat_check/patches/#{ce_patch_name}"
    end

    def step(desc, cmd = nil)
      puts "\n=> #{desc}\n"

      if cmd
        start = Time.now
        puts "\n$ #{cmd.join(' ')}"

        output, status = command(cmd)
        puts "\n==> Finished in #{Time.now - start} seconds"

        if block_given?
          yield(output, status)
        else
          [output, status]
        end
      end
    end

    def command(cmd)
      Gitlab::Popen.popen(cmd)
    end

    def applies_cleanly_msg(branch)
      %Q{
        #{PLEASE_READ_THIS_BANNER}
        🎉 Congratulations!! 🎉

        The `#{branch}` branch applies cleanly to EE/master!

        Much ❤️! For more information, see
        https://docs.gitlab.com/ce/development/limit_ee_conflicts.html#check-the-rake-ee_compat_check-in-your-merge-requests
        #{THANKS_FOR_READING_BANNER}
      }
    end

    def ce_branch_doesnt_apply_cleanly_and_no_ee_branch_msg
      %Q{
        #{PLEASE_READ_THIS_BANNER}
        💥 Oh no! 💥

        The `#{ce_branch}` branch does not apply cleanly to the current
        EE/master, and no `#{ee_branch_prefix}` or `#{ee_branch_suffix}` branch
        was found in the EE repository.

        #{conflicting_files_msg}

        We advise you to create a `#{ee_branch_prefix}` or `#{ee_branch_suffix}`
        branch that includes changes from `#{ce_branch}` but also specific changes
        than can be applied cleanly to EE/master. In some cases, the conflicts
        are trivial and you can ignore the warning from this job. As always,
        use your best judgment!

        There are different ways to create such branch:

        1. Create a new branch from master and cherry-pick your CE commits

          # In the EE repo
          $ git fetch origin
          $ git checkout -b #{ee_branch_prefix} origin/master
          $ git fetch #{ce_repo} #{ce_branch}
          $ git cherry-pick SHA # Repeat for all the commits you want to pick

          You can squash the `#{ce_branch}` commits into a single "Port of #{ce_branch} to EE" commit.

        2. Apply your branch's patch to EE

          # In the EE repo
          $ git fetch origin master
          $ git checkout -b #{ee_branch_prefix} origin/master
          $ wget #{patch_url}
          $ git apply --3way #{ce_patch_name}

          At this point you might have conflicts such as:

            error: patch failed: lib/gitlab/ee_compat_check.rb:5
            Falling back to three-way merge...
            Applied patch to 'lib/gitlab/ee_compat_check.rb' with conflicts.
            U lib/gitlab/ee_compat_check.rb

          Resolve them, stage the changes and commit them.

          If the patch couldn't be applied cleanly, use the following command:

          # In the EE repo
          $ git apply --reject #{ce_patch_name}

          This option makes git apply the parts of the patch that are applicable,
          and leave the rejected hunks in corresponding `.rej` files.
          You can then resolve the conflicts highlighted in `.rej` by
          manually applying the correct diff from the `.rej` file to the file with conflicts.
          When finished, you can delete the `.rej` files and commit your changes.

        ⚠️ Don't forget to push your branch to gitlab-ee:

          # In the EE repo
          $ git push origin #{ee_branch_prefix}

        ⚠️ Also, don't forget to create a new merge request on gitlab-ee and
        cross-link it with the CE merge request.

        Once this is done, you can retry this failed build, and it should pass.

        Stay 💪 ! For more information, see
        https://docs.gitlab.com/ce/development/limit_ee_conflicts.html#check-the-rake-ee_compat_check-in-your-merge-requests
        #{THANKS_FOR_READING_BANNER}
      }
    end

    def ee_branch_doesnt_apply_cleanly_msg
      %Q{
        #{PLEASE_READ_THIS_BANNER}
        💥 Oh no! 💥

        The `#{ce_branch}` does not apply cleanly to the current EE/master, and
        even though a `#{ee_branch_found}` branch
        exists in the EE repository, it does not apply cleanly either to
        EE/master!

        #{conflicting_files_msg}

        Please update the `#{ee_branch_found}`, push it again to gitlab-ee, and
        retry this build.

        Stay 💪 ! For more information, see
        https://docs.gitlab.com/ce/development/limit_ee_conflicts.html#check-the-rake-ee_compat_check-in-your-merge-requests
        #{THANKS_FOR_READING_BANNER}
      }
    end

    def conflicting_files_msg
      failed_files.reduce("The conflicts detected were as follows:\n") do |memo, file|
        memo << "\n        - #{file}"
      end
    end
  end
end
