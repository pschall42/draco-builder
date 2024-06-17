# frozen_string_literal: true

module Difficulty
  class << self

    def enemy_ability_point_costs_per_point
      # Damage = Attack - Shield
      {
        # Difficulty can be increased by being a big bag of health, increasing the threat level, becoming tankier, or by making prediction more difficult
        hp: 1,
        attack: 2,
        shield_value: 4,
        shield_absorption_mult: 8,
        shield_slot: 8, # Have to buy shield slots first
        # It can also be increased via regen values
        hp_regen: 5,
        attack_regen: 10, # Used when couter when attack is weakened
        shield_value_regen: 20,
        shield_absorption_regen: 40,
        # Delivering bullets toward the player faster and more confusingly than ever before
        bullet_velocity: 3,       # 2**1 + 2**0
        bullet_acceleration: 6,   # 2**2 + 2**1
        bullet_jerk: 12,          # 2**3 + 2**2
        bullet_snap: 24,          # 2**4 + 2**3
        bullet_crackle: 48,       # 2**5 + 2**4
        bullet_pop: 96,           # 2**6 + 2**5
        # Allow bullets to home in on the player, can have interesting/confusing effects when paired with the other bullet modifiers
        bullet_homing_velocity: 7,        # 2**2 + 2**1 + 2**0
        bullet_homing_acceleration: 14,   # 2**3 + 2**2 + 2**1
        bullet_homing_jerk: 28,           # 2**4 + 2**3 + 2**2
        bullet_homing_snap: 56,           # 2**5 + 2**4 + 2**3
        bullet_homing_crackle: 112,       # 2**6 + 2**5 + 2**4
        bullet_homing_pop: 224,           # 2**7 + 2**6 + 2**5
        # Bullet effects (applied to an enemy)
        bullet_effect_slot: 10, # Have to buy effect slots first
        bullet_effect_slow: 40,
        bullet_effect_weaken_attack: 10,
        bullet_effect_weaken_shield_value: ,
        bullet_effect_weaken_shield_absorption: ,
        bullet_effect_weaken_hp_regen: ,
        bullet_effect_weaken_attack_regen: ,
        bullet_effect_weaken_shield_value_regen: ,
        bullet_effect_weaken_shield_absorption_regen: ,
        bullet_effect_nullify_attack: ,
        bullet_effect_nullify_shield_value: ,
        bullet_effect_nullify_shield_absorption: , # This effectively destroys a shield, so it should cost the most
        bullet_effect_nullify_hp_regen: ,
        bullet_effect_nullify_attack_regen: ,
        bullet_effect_nullify_shield_value_regen: ,
        bullet_effect_nullify_shield_absorption_regen: ,
        # Bullet attributes
        bullet_size: ,
        bullet_speed: ,
        bullet_rate_of_fire: ,
        bullet_split_timer: ,
        bullet_spread: ,
        bullet_angular_momentum: ,
      }
    end

    def enemy_ability_points(enemy_difficulty_rating)
      Math.floor(enemy_difficulty_rating * 10)
    end

    # Finds the overall difficulty of a specific wave
    def wave_difficulty(growth_fn, noise_fn, wave, phases_per_wave, turns_per_phase, difficulty_scale: 1)
      phases_per_wave.times.reduce(0){|acc, phase_idx|
        acc + self.phase_difficulty(growth_fn, noise_fn, wave, phase_idx + 1, phases_per_wave, turns_per_phase, difficulty_scale: difficulty_scale)
      }
    end

    # Finds the overall difficulty of a specific phase, increasing the difficulty as phases progress
    def phase_difficulty(growth_fn, noise_fn, wave, phase, phases_per_wave, turns_per_phase, difficulty_scale: 1)
      turns_per_phase.times.reduce(0){|acc, turn_idx|
        acc + self.turn_difficulty(growth_fn, noise_fn, wave, phase, phases_per_wave, turn_idx + 1, turns_per_phase, difficulty_scale: difficulty_scale)
      }
    end

    # Only makes sense in calculating partial difficulty for the overall phase, because enemies are generated on a phase basis and not a turn basis. Effectively it can be used to generate roughly how often enemies should be generated though.
    def turn_difficulty(growth_fn, noise_fn, wave, phase, phases_per_wave, turn, turns_per_phase, difficulty_scale: 1)
      turns_per_wave = phases_per_wave * turns_per_phase
      tpw_progress = turn / turns_per_wave.to_f
      ppw_progress = phase / phases_per_wave.to_f

      wave_progress = ppw_progress * tpw_progress
      total_n = wave + wave_progress

      difficulty = difficulty_scale * (growth_fn.call(total_n) + noise_fn.call(total_n))

      # If we're at infinity, clamp to Float::MAX
      [difficulty, Float::MAX].min
    end

    # Builtin growth functions
    def growth_function(growth_rate, log_fn: :log, exp_base: 2, exp_power: 2, constant: 1)
      case growth_rate
      when :constant # Pushover
        lambda{|_n| constant }
      when :log_n # Very Easy
        # We add 1 to log arguments to prevent negative values
        lambda{|n| Math.send(log_fn, n + 1) }
      when :n # Easy
        lambda{|n| n }
      when :n_log_n # Normal
        # We add 1 to log arguments to prevent negative values
        lambda{|n| n * Math.send(log_fn, n + 1) }
      when :n_exp # Very Hard
        lambda{|n| n ** exp_power }
      when :exp_n # Ludicrously Hard
        # NOTE: Can reach wave 1023 (under base 2), afterwards going to Infinity
        lambda{|n| exp_base ** n }
      when :fact, :gamma # Impossible
        # NOTE: Can reach wave 171, afterwards going to Infinity
        lambda{|n| Math.gamma(n + 1) }
      end
    end

    def difficulty_growth_function(difficulty_sym, log_fn: :log, exp_base: 2)
      DIFFICULTY_GROWTH_FUNCTIONS[difficulty_sym]
    end

    # Quick wat to visually inspect each difficulty's rating and growth over time
    def test(wave, phases_per_wave, turns_per_phase, noise_fn: nil, log_fn: :log, exp_base: 2)
      noise_fn ||= lambda{|n| 0 }
      DIFFICULTY_GROWTH_FUNCTIONS.reduce({}){|acc, (difficulty_key, growth_fn)|
        # Normal is at index 3, so take 2^(idx - 3) to get the scale for anything easier
        relative_difficulty = DIFFICULTY_GROWTH_FUNCTIONS.keys.index(difficulty_key) - 3
        difficulty_scale = (relative_difficulty < 0) ? (2.0 ** relative_difficulty) : (relative_difficulty + 2) / 2
        acc[difficulty_key] = self.wave_difficulty(growth_fn, noise_fn, wave, phases_per_wave, turns_per_phase, difficulty_scale: difficulty_scale)
        acc
      }
    end
  end
  # Basic difficulty growth functions
  DIFFICULTY_GROWTH_FUNCTIONS = {
    pushover: self.growth_function(:constant),
    very_easy: self.growth_function(:log_n),
    easy: self.growth_function(:n),
    normal: self.growth_function(:n_log_n),
    hard: lambda{|n|
      # We add 1 to log arguments to prevent negative values
      (n ** 1.25) * Math.log((n + 1) ** 1.25)
    },
    very_hard: self.growth_function(:n_exp),
    ludicrously_hard: self.growth_function(:exp_n),
    impossible: self.growth_function(:fact)
  }
end