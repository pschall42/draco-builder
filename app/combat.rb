# frozen_string_literal: true

module Combat
  class << self
    # Agent stats should be passed in with the following format:
    #   {
    #     # HP
    #     hp: {v: <hp_value>, max: <hp_max_value>},
    #     hp_regen: {v: <hp_regen_value>},
    #
    #     # Attack
    #     attack: {v: <attack_value>, max: <attack_max_value>},
    #     attack_regen: {v: <attack_regen_value>},
    #
    #     # Shields
    #     shield_1: {v: <shield_value_1>, absorbed: <shield_absorb_1>, max_absorb: <shield_max_absorb_1>},
    #     shield_2: {v: <shield_value_2>, absorbed: <shield_absorb_2>, max_absorb: <shield_max_absorb_2>},
    #     ...
    #     shield_n: {v: <shield_value_n>, absorbed: <shield_absorb_n>, max_absorb: <shield_max_absorb_n>},
    #
    #     # Shields regen
    #     shield_regen_1: {v: <shield_regen_value_1>, absorbed: <shield_regen_absorb_1>, max_absorb: <shield_regen_max_absorb_1>},
    #     shield_regen_2: {v: <shield_regen_value_2>, absorbed: <shield_regen_absorb_2>, max_absorb: <shield_max_absorb_2>},
    #     ...
    #     shield_regen_n: {v: <shield_regen_value_n>, absorbed: <shield_regen_absorb_n>, max_absorb: <shield_regen_max_absorb_n>},
    #   }
    def agent_stats_mechanics(obj_hash)
      # Dynamically determine all the shield components that need integration
      all_shield_components = obj_hash.keys.select{|key| key =~ /^shield/ }
      shield_slot_integration_hash = obj_hash.keys.reduce({}){|acc, key|
        if !acc.key?(key) && !(key_match_data = key.to_s.match(/^shield(_regen)?_(\d)/)).nil?
          acc[:"shield_#{key_match_data[2]}"] = :"shield_regen_#{key_match_data[2]}"
        end
        acc
      }
      # Integrate components
      components = MathExt.numeric_integration(obj_hash, {
        hp: :hp_regen,
        attack: :attack_regen,
        **shield_slot_integration_hash
      })
      # TODO: Implement clamp_components
      components = MaxExt.clamp_components(components, {
        hp: {v: {max: :max}},
        attack: {v: {max: :max}},
        # Clamp all shield slots max absorbed value
        **(shield_slot_integration_hash.reduce({}){|acc, (shield_slot_key, _value)|
          acc[shield_slot_key] = {absorbed: {max: :max_absorb}}
          acc
        })
      })

      # Set components
      components.each{|comp_name, comp|
        obj_hash[comp_name] = comp
      }
    end
  end
end