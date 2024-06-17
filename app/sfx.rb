# frozen_string_literal: true

module SFX
  class << self
    # https://sfxr.me

    def bgm
      {input: 'sounds/flight.ogg', looping: true}
    end

    def title_bgm
      {
        input: "sounds/Evening_Melodrama.ogg",
        gain: 1.0,
        pitch: 1.0,
        looping: true
      }
    end
    def gameplay_bgm
      {
        input: "sounds/Peritune_Zephyr_Fields-chosic.com_.ogg",
        gain: 0.5,
        pitch: 1.0,
        looping: true
      }
    end

    def start_or_crossfade_music(audio, music_key, next_music_hash)
      current_music = audio[music_key]
      if current_music.nil?
        # Start the music immediately
        audio[music_key] = next_music_hash
      elsif current_music.input != next_music_hash.input
        # Only need to crossfade if not starting new music
        self.start_crossfade(audio, music_key, next_music_hash)
      end
    end

    def start_crossfade(audio, music_key, next_music_hash)
      # https://docs.dragonruby.org/#/api/audio?id=advanced-audio-manipulation-crossfade
      fade_music_key = :"#{music_key}_fade"
      current_music = audio[music_key]
      audio[fade_music_key] = current_music&.slice(:input, :gain, :pitch, :looping, :playtime)
      new_music = next_music_hash.merge(gain: 0, target_gain: next_music_hash[:gain])
      audio[music_key] = new_music
    end

    def process_crossfade(audio, music_key, norm_percentage)
      fade_music_key = :"#{music_key}_fade"
      fade_music = audio[fade_music_key]
      current_music = audio[music_key]
      # Increase volume of music until target gain is reached
      if [:gain, :target_gain].all?{|k| current_music&.key?(k) || false } && (current_music.gain < current_music.target_gain)
        current_music.gain = (current_music.gain + norm_percentage).clamp(current_music.gain, current_music.target_gain)
      end
      # Decrease volume of fade music until 0, then delete
      if fade_music&.key?(:gain) && fade_music.gain > 0
        fade_music.gain -= norm_percentage
        audio[fade_music_key] = nil if fade_music.gain <= 0
      end
    end

    def start_game
      'sounds/game-over.wav'
    end

    def spawn_fireball
      'sounds/fireball.wav'
    end

    def target_destroyed
      'sounds/target.wav'
    end

    def game_over
      'sounds/game-over.wav'
    end
  end
end
