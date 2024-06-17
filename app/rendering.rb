# frozen_string_literal: true

module Rendering
  class << self
    def player_state_to_sprite_output(player)
      # {
      #   x: player_hash.dig(:transforms, :position).position.x,
      #   y: player_hash.dig(:transforms, :position).position.y,
      #   w: player_hash.dig(:dimensions, :w) * player_hash.dig(:transforms, :position).scale.x,
      #   h: player_hash.dig(:dimensions, :h) * player_hash.dig(:transforms, :position).scale.y,
      #   path: player_hash[:sprite]
      # }
      player.to_render_hash
    end
    def fireballs_state_to_sprite_output(fireballs)
      fireballs.map(&:to_render_hash)
    end
    def targets_state_to_sprite_output(targets)
      targets.flat_map{|target|
        # puts target_hash.dig(:collider).inspect
        [
          # {
          #   x: target_hash.dig(:transforms, :position).position.x,
          #   y: target_hash.dig(:transforms, :position).position.y,
          #   w: target_hash.dig(:dimensions, :w) * target_hash.dig(:transforms, :position).scale.x,
          #   h: target_hash.dig(:dimensions, :h) * target_hash.dig(:transforms, :position).scale.x,
          #   path: target_hash[:sprite]
          # },
          # {
          #   x: target_hash.dig(:collider).center[0] - target_hash.dig(:collider).radius,
          #   y: target_hash.dig(:collider).center[1] - target_hash.dig(:collider).radius,
          #   w: target_hash.dig(:collider).radius * 2 * target_hash.dig(:transforms, :position).scale.x,
          #   h: target_hash.dig(:collider).radius * 2 * target_hash.dig(:transforms, :position).scale.y,
          #   path: 'sprites/misc/target.png',
          #   r: 0,
          #   g: 0,
          #   b: 255
          # },
          target.to_render_hash,
          # {
          #   **target.to_render_hash,
          #   r: 0,
          #   g: 0,
          #   b: 0,
          #   a: 127
          # }
        ]
      }
    end
  end
end
