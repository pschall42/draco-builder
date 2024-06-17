# frozen_string_literal: true

require_relative 'physics'

module Projectiles
  class << self
    def fireball_orig(player_hash)
      fireball_dimensions = {
        w: 32,
        h: 32
      }
      player_w = player_hash.dig(:dimensions, :w) * player_hash.dig(:transforms, :position).scale.x
      player_h = player_hash.dig(:dimensions, :h) * player_hash.dig(:transforms, :position).scale.y
      # We want the position near the mouth of the dragon, and we want the fireball to be centered
      relative_position = {
        x: player_w - (fireball_dimensions[:w] / 2.0), # Want it at the end of the dragon
        y: player_h * (25 / 80.0) - (fireball_dimensions[:h] / 2.0) # At ~55 of 80 px from the top (25 px from the bottom)
      }
      {
        transforms: {
          position: Physics::Transform.from(player_hash.dig(:transforms, :position)).tap{|transform|
            transform.position.x += relative_position[:x]
            transform.position.y += relative_position[:y]
          },
          velocity: Physics::Transform.new([player_hash[:speed] + 12, 0], 0, [0, 0]),
        },
        # position: (fireball_center = {
        #   x: player_hash[:position][:x] + relative_position[:x],
        #   y: player_hash[:position][:y] + relative_position[:y],
        # }),
        # velocity: {
        #   # x: player_hash[:speed] + 12
        #   x: 2
        # },
        # acceleration: {
        #   x: 2,
        #   y: 0
        # },
        # pop: {x: 0.001, y: 0},
        dimensions: fireball_dimensions,
        sprite: 'sprites/misc/fireball.png',
        collider: Physics::Colliders.circle([0, 0], 16)
      }
    end

    def fireball(player)
      # Fireball is 22 px wide and 18 px high (ing)
      fireball_diameter = 32
      # Fireball is 22 px wide and 18 px high (ignoring transparency), so take average of 20
      sprite_px_w = sprite_px_h = 32
      fireball_diameter = 20
      fireball_radius = fireball_diameter / 2.0
      player_pos_x, player_pos_y = player.position.x, player.position.y
      player_center_x, player_center_y = player.collider.center
      player_w = player.dimensions.w
      player_h = player.dimensions.h
      cos_angle = Math.cos(player.angle.to_radians)
      sin_angle = Math.sin(player.angle.to_radians)
      # We want the position near the mouth of the dragon, and we want the fireball to be centered
      # relative_position_without_rotation = [
      #   (player_w / 2.0) - fireball_radius, # X: Want it at the end of the dragon
      #   (player_h / 2.0) * (25 / 80.0) - fireball_radius, # Y: At ~55 of 80 px from the top (25 px from the bottom)
      #   1 # Z: Identity
      # ]
      relative_position_without_rotation = [
        -fireball_radius, # X: Want it at the end of the dragon
        0, # Y: At ~55 of 80 px from the top (25 px from the bottom)
        1 # Z: Identity
      ]
      fireball_x, fireball_y, _fireball_z = MathExt::Matrix.multiply(player.transforms.position.transformation_matrix, relative_position_without_rotation).flatten
      # puts "result: #{result.inspect}"
      # relative_position = {
      #   x: ((player_center_x + (player_w / 2.0) - player_pos_x) - fireball_radius), # Want it at the end of the dragon
      #   y: ((player_center_y + (player_h / 2.0) - player_pos_y) * (25 / player_h) - fireball_radius) # At ~55 of 80 px from the top (25 px from the bottom)
      # }

      # relative_position = {
      #   x: (player_w / 2.0), # Want it at the end of the dragon
      #   y: (player_h / 2.0) # At ~55 of 80 px from the top (25 px from the bottom)
      # }
      relative_speed = player.data[:speed] + 12

      GameObject.new(
        transforms: {
          position: {
            position: {
              # x: player.position.x + relative_position[:x],
              # y: player.position.y + relative_position[:y],
              x: fireball_x,
              y: fireball_y
            },
            angle_position: {theta: player.angle},
            scale_position: {x: 1, y: 1}
          },
          velocity: {
            velocity: {
              x: relative_speed * cos_angle,
              y: relative_speed * sin_angle
            },
            angle_velocity: {theta: 0},
            scale_velocity: {x: 0, y: 0}
          }

          # TESTING:
          # velocity: {
          #   velocity: {x: 0.00000001, y: 0},
          #   angle_velocity: {theta: 0},
          #   scale_velocity: {x: 0, y: 0}
          # }
          # acceleration: {
          #   acceleration: {x: 0.00000001, y: 0},
          #   angle_acceleration: {theta: 0},
          #   scale_acceleration: {x: 0, y: 0}
          # }
          # jerk: {
          #   jerk: {x: 0.00000001, y: 0},
          #   angle_jerk: {theta: 0},
          #   scale_jerk: {x: 0, y: 0}
          # }
          # snap: {
          #   snap: {x: 0.00000001, y: 0},
          #   angle_snap: {theta: 0},
          #   scale_snap: {x: 0, y: 0}
          # }
          # crackle: {
          #   crackle: {x: 0.00000001, y: 0},
          #   angle_crackle: {theta: 0},
          #   scale_crackle: {x: 0, y: 0}
          # }
          # pop: {
          #   pop: {x: 0.0000000001, y: 0},
          #   angle_pop: {theta: 0},
          #   scale_pop: {x: 0, y: 0}
          # }
        },
        dimensions: {
          w: sprite_px_w,
          h: sprite_px_h
        },
        data: {
          start_tick: $gtk.args.state.tick_count
        },
        sprite: 'sprites/misc/fireball-0.png',
        collider: Physics::Colliders.circle([0, 0], fireball_radius)
      )
      # .tap{|fb|
      #   puts fb.to_render_hash.inspect
      # }
    end
  end
end