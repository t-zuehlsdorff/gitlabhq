module Gitlab
  module Utils
    extend self

    # Run system command without outputting to stdout.
    #
    # @param  cmd [Array<String>]
    # @return [Boolean]
    def system_silent(cmd)
      Popen.popen(cmd).last.zero?
    end

    def force_utf8(str)
      str.force_encoding(Encoding::UTF_8)
    end

    # A slugified version of the string, suitable for inclusion in URLs and
    # domain names. Rules:
    #
    #   * Lowercased
    #   * Anything not matching [a-z0-9-] is replaced with a -
    #   * Maximum length is 63 bytes
    #   * First/Last Character is not a hyphen
    def slugify(str)
      return str.downcase
        .gsub(/[^a-z0-9]/, '-')[0..62]
        .gsub(/(\A-+|-+\z)/, '')
    end

    def to_boolean(value)
      return value if [true, false].include?(value)
      return true if value =~ /^(true|t|yes|y|1|on)$/i
      return false if value =~ /^(false|f|no|n|0|off)$/i

      nil
    end

    def boolean_to_yes_no(bool)
      if bool
        'Yes'
      else
        'No'
      end
    end
  end
end
