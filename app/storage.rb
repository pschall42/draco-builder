# frozen_string_literal: true

module Storage
  class << self
    # aoh_2_hoa ≅ hoa_2_aoh
    # Array of Hashes -> Hash of Arrays
    # [ {a: 'a', b: 'b'}, {b: 5, c: 'c'}, {d: 4, e: 'e'}, {y: 'why', z: 'zed'} ]
    def aoh_2_hoa(aoh)
      keys = aoh.reduce([]){|acc, hash| acc |= hash.keys }
      values = aoh.reduce([]){|acc, hash| acc.size == 0 ? keys.map{|k| [hash[k]]} : acc.zip(hash.values_at(*keys)).map(&:flatten)}
      keys.zip(values).to_h
    end
    # Hash of Arrays -> Array of Hashes
    def hoa_2_aoh(hoa)
      hoa.reduce([]){|acc, (key, values)|
        values.each_with_index{|v, idx|
          acc_hash = acc[idx] || {}
          acc[idx] = acc_hash.merge({key => v}).compact
        }
        acc
      }
    end
  end
end