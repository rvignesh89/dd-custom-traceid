# frozen_string_literal: true

require 'digest'

module ZenGithub
  class Id
    MAX = ((1 << 62) - 1)

    def self.generate(repo, pr_num)
      # A MD5 hash has 128 bits. A DD trace-id cannot be larger than (1 << 62)
      # -1 (https://github.com/DataDog/dd-trace-rb/blob/master/lib/datadog/tracing/span.rb#L28)
      # In the code below we take the last 15 characters from a hexdigest of
      # length 32 and generate an integer from it. This was the integer will
      # never be more than 60 bits
      # Example,
      # Digest::MD5.hexdigest "repo#12333" = d73010bc3173c4b6914cf16fbdbf54fa
      # last 15 chars = 14cf16fbdbf54fa
      # as binary string = [ "1000", "1000", "1100", "1111", "1000", "1100",
      #                       "1111", "1011", "1101", "1011", "1111", "1010",
      #                       "1000", "1111", "1010"]
      # as a string =
      # 100010001100111110001100111110111101101111111010100011111010
      # as integter = 616140820168288506

      id = (Digest::MD5.hexdigest "#{repo}/#{pr_num}")[-15..32].chars.map do |c|
        c.hex.to_s(2).ljust(4, '0')
      end.reduce(&:+).to_i(2)

      raise Error("id #{id} > #{MAX}") if id > MAX

      id
    end
  end
end
