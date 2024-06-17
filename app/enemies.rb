# frozen_string_literal: true

require_relative 'game_object'

module Enemies
  class << self
    # def target_orig(x, y)
    #   target_bl_position = Physics::Transform.new([x, y], 0, [1, 1])
    #   target_diameter = 64
    #   target_radius = target_diameter / 2.0
    #   target_center = target_bl_position.position.to_h.reduce({}){|acc, (coord, coord_min)|
    #     acc[coord] = coord_min + target_radius
    #     acc
    #   }
    #   {
    #     transforms: {
    #       position: target_bl_position
    #     },
    #     dimensions: {
    #       w: target_diameter,
    #       h: target_diameter
    #     },
    #     sprite: 'sprites/misc/target.png',
    #     collider: Physics::Colliders.circle([0, 0], target_radius)
    #   }
    # end

    def target(x, y)
      target_diameter = 64
      target_radius = target_diameter / 2.0
      GameObject.new(
        transforms: {
          position: {
            position: {x: x, y: y},
            angle_position: {theta: 0},
            scale_position: {x: 1, y: 1}
          }
        },
        dimensions: {
          w: target_diameter,
          h: target_diameter
        },
        sprite: 'sprites/misc/target.png',
        collider: Physics::Colliders.circle([0, 0], target_radius)
      )
    end
  end
end
