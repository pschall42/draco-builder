# frozen_string_literal: true

require_relative 'physics/colliders'
require_relative 'projectiles'
require_relative 'sfx'

module Input
  class << self
    # Control Scheme:
    #   Keyboard:
    #     WASD  - Movement
    #     IJKL  - Look/Rotate
    #     Space - Fire
    #     UO    - Cycle cards
    #     E     - Play selected card
    #     T     - Pass turn (discard + redraw hand, advance wave by turn time remaining)
    #     Q     - Next wave (advance next wave timer to 0)
    #   Controller:
    #     Left Stick  - Movement
    #     Right Stick - Look/Rotate
    #     RT          - Fire
    #     LB/RB       - Cycle cards
    #     A           - Play selected card
    #     Y           - Pass turn (discard + redraw hand, advance wave by turn time remaining)
    #     X           - Next wave (advance next wave timer to 0)
    # Follows the same pattern as GTK::Inputs#left_right_perc, but with added thresholds for the controller and restricted keyboard key checking
    def move_left_right_percent(inputs)
      analog_x = inputs.controller_one.left_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.left_analog_x_perc : 0.0
      return analog_x if analog_x != 0.0
      a_pressed = inputs.keyboard.a
      d_pressed = inputs.keyboard.d
      return -1.0 if a_pressed && !d_pressed
      return 1.0 if !a_pressed && d_pressed
      return 0.0
    end
    def move_up_down_percent(inputs)
      analog_y = inputs.controller_one.left_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.left_analog_y_perc : 0.0
      return analog_y if analog_y != 0.0
      w_pressed = inputs.keyboard.w
      s_pressed = inputs.keyboard.s
      return 1.0 if w_pressed && !s_pressed
      return -1.0 if !w_pressed && s_pressed
      return 0.0
    end
    def move_angle_degrees(inputs)
      analog_angle_degrees = inputs.controller_one.left_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.left_analog_angle : nil
      analog_angle_degrees || Math.atan2(self.move_up_down_percent(inputs), self.move_left_right_percent(inputs)).to_degrees
    end
    def move_angle_radians(inputs)
      analog_angle_degrees = inputs.controller_one.left_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.left_analog_angle : nil
      analog_angle_degrees&.to_radians || Math.atan2(self.move_up_down_percent(inputs), self.move_left_right_percent(inputs))
    end

    def rotate_left_right_percent(inputs)
      analog_x = inputs.controller_one.right_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.right_analog_x_perc : 0.0
      return analog_x if analog_x != 0.0
      j_pressed = inputs.keyboard.j
      l_pressed = inputs.keyboard.l
      return -1.0 if j_pressed && !l_pressed
      return 1.0 if !j_pressed && l_pressed
      return 0.0
    end
    def rotate_up_down_percent(inputs)
      analog_y = inputs.controller_one.right_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.right_analog_y_perc : 0.0
      return analog_y if analog_y != 0.0
      i_pressed = inputs.keyboard.i
      k_pressed = inputs.keyboard.k
      return 1.0 if i_pressed && !k_pressed
      return -1.0 if !i_pressed && k_pressed
      return 0.0
    end
    def rotate?(inputs)
      inputs.controller_one.right_analog_active?(threshold_perc: 0.15) || inputs.keyboard.i || inputs.keyboard.j || inputs.keyboard.k || inputs.keyboard.l
    end
    def rotate_angle_degrees(inputs)
      analog_angle_degrees = inputs.controller_one.right_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.right_analog_angle : nil
      analog_angle_degrees || Math.atan2(self.rotate_up_down_percent(inputs), self.rotate_left_right_percent(inputs)).to_degrees
    end
    def rotate_angle_radians(inputs)
      analog_angle_degrees = inputs.controller_one.right_analog_active?(threshold_perc: 0.15) ? inputs.controller_one.right_analog_angle : nil
      analog_angle_degrees&.to_radians || Math.atan2(self.rotate_up_down_percent(inputs), self.rotate_left_right_percent(inputs))
    end

    # GTK::Controller keys are:
    #   LT - :l2
    #   LB - :l1
    #   RT - :r2
    #   RB - :r1
    # Currently it doesn't support trigger percentages or thresholds, treating them as regular buttons, and returning either `nil` or an integer representing the tick_count it was pressed.
    def firing_percent(inputs)
      analog_z = inputs.controller_one.r2 ? 1.0 : 0.0
      return analog_z if analog_z != 0.0
      return 1.0 if inputs.keyboard.space
      return 0.0
    end

    # We want to increase cycle speed based on how many ticks have passed
    def cycle_card_percent(inputs, ticks_threshold: 0, held_ticks_max: 0)
      # Initialize the current tick count and ensure the max held ticks is a Float
      current_tick_count = tick_count()
      held_ticks_max = held_ticks_max.to_f
      # Find the earliest tick for each held input
      cycle_right_tick = inputs.controller_one.r1 ||
      cycle_left_tick = inputs.controller_one.l1 ||
      # Find how long each button has been held
      cycle_right_held_ticks = current_tick_count - cycle_right_tick
      cycle_left_held_ticks = current_tick_count - cycle_left_tick
      # Find the respective percentages
      cycle_right_percent = (cycle_right_held_ticks > held_ticks_max) ? 1.0 : (cycle_right_held_ticks / held_ticks_max)
      cycle_left_percent = (cycle_left_held_ticks > held_ticks_max) ? 1.0 : (cycle_left_held_ticks / held_ticks_max)
      # Return the difference between the percentages (ranging between -1.0 and 1.0)
      cycle_right_percent - cycle_left_percent
    end

    def play_card_pressed?(inputs)
      inputs.controller_one.key_down.a || inputs.keyboard.key_down.e
    end

    def pass_turn_pressed?(inputs)
      inputs.controller_one.key_down.y || inputs.keyboard.key_down.t
    end

    def next_wave_pressed?(inputs)
      inputs.controller_one.key_down.x || inputs.keyboard.key_down.q
    end

    # Rendering info for controls
    def keyboard_controls_info(grid)
      [
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75 - 10,
          y: (grid.h / 2.0) + 60,
          # text: "WASD to move, IJKL to rotate, UO to cycle through cards, E to play a card Space to fire, Q to call the next wave, T to discard and redraw your hand"
          text: "Keyboard Controls",
          size_enum: 2
        },
        {
          x: (grid.w / 6.0) - 75 + 200,
          y: (grid.h / 2.0) + 20,
          # text: "WASD to move, IJKL to rotate, UO to cycle through cards, E to play a card Space to fire, Q to call the next wave, T to discard and redraw your hand"
          text: "WASD to move"
        },
        {
          x: (grid.w / 6.0) - 75 + 200,
          y: (grid.h / 2.0),
          text: "IJKL to rotate"
        },
        {
          x: (grid.w / 6.0) - 75 + 200,
          y: (grid.h / 2.0) - 20,
          text: "Space to fire"
        },
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75,
          y: (grid.h / 2.0) + 20,
          text: "UO to cycle cards"
        },
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75,
          y: (grid.h / 2.0),
          text: "E to play a card"
        },
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75,
          y: (grid.h / 2.0) - 20,
          text: "T to pass the turn"
        },
        {
          x: (grid.w / 3.0) * 2 + (grid.w / 6.0) - 275,
          y: (grid.h / 2.0),
          text: "Q to call the next wave"
        }
      ]
    end
    def gamepad_controls_info(grid)
      [
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75 - 10,
          y: (grid.h / 2.0) + 60,
          # text: "WASD to move, IJKL to rotate, UO to cycle through cards, E to play a card Space to fire, Q to call the next wave, T to discard and redraw your hand"
          text: "Gamepad Controls",
          size_enum: 2
        },
        {
          x: (grid.w / 6.0) - 75 + 200 - 35,
          y: (grid.h / 2.0) + 20,
          # text: "WASD to move, IJKL to rotate, UO to cycle through cards, E to play a card Space to fire, Q to call the next wave, T to discard and redraw your hand"
          text: "Left Stick to move"
        },
        {
          x: (grid.w / 6.0) - 75 + 200 - 35,
          y: (grid.h / 2.0),
          text: "Right Stick to rotate"
        },
        {
          x: (grid.w / 6.0) - 75 + 200 - 35,
          y: (grid.h / 2.0) - 20,
          text: "RT to fire"
        },
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75 - 10,
          y: (grid.h / 2.0) + 20,
          text: "LB/RB to cycle cards"
        },
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75 - 10,
          y: (grid.h / 2.0),
          text: "A to play a card"
        },
        {
          x: (grid.w / 3.0) + (grid.w / 6.0) - 75 - 10,
          y: (grid.h / 2.0) - 20,
          text: "Y to pass the turn"
        },
        {
          x: (grid.w / 3.0) * 2 + (grid.w / 6.0) - 275 + 10,
          y: (grid.h / 2.0),
          text: "X to call the next wave"
        }
      ]
    end

    def handle_input(inputs, player, projectiles, sounds, &block)
      movement_info = self.handle_movement(inputs, player)
      rotation_info = self.handle_rotation(inputs, player)
      self.handle_firing(inputs, player, projectiles, sounds)
      block.call(movement_info.merge(rotation_info)) if !block.nil?
    end

    def handle_restart_input(inputs, player, projectiles)
      valid_inputs = {
        keyboard: [:z, :j, :space],
        controller_one: [:a]
      }
      is_firing = valid_inputs.any?{|interface, keys_or_buttons|
        keys_or_buttons.any?{|key_or_button|
          inputs.send(interface).key_down.send(key_or_button)
        }
      }
      $gtk.reset if is_firing
    end

    def key_pressed?(interface, key_sym)
      interface.key_down.send(key_sym)
    end

    def is_firing?(inputs)
      self.firing_percent(inputs) > 0
    end

    def handle_firing(inputs, player, projectiles, sounds)
      if self.is_firing?(inputs)
        sounds << SFX.spawn_fireball
        projectiles << Projectiles.fireball(player)
      end
    end

    def handle_movement(inputs, player)
      # Find the appropriate speed components based on movement angle
      speed = player.data.speed
      angle_rad = self.move_angle_radians(inputs)
      x_speed = (player.data.speed * Math.cos(angle_rad)).abs
      y_speed = (player.data.speed * Math.sin(angle_rad)).abs

      # Find horizontal and vertical multipliers based on input
      horizontal_mult = self.move_left_right_percent(inputs)
      vertical_mult = self.move_up_down_percent(inputs)

      # Move
      player.position.x += horizontal_mult * x_speed
      player.position.y += vertical_mult * y_speed
      # if scale_x_sign_change != 0
      #   player.scale.x = player.scale.x.abs * scale_x_sign_change
      # end

      # Return movement data
      return {
        movement: {
          speed: speed,
          angle_radians: angle_rad,
          x_speed: x_speed,
          y_speed: y_speed,
          horizontal: horizontal_mult,
          vertical: vertical_mult
        }
      }
    end

    def handle_rotation(inputs, player)
      # Flip horizontally when rotated between 90 and 270 degrees
      # puts "BEFORE scale: #{player.scale.to_h.inspect}, angle: #{angle_degrees}"
      if self.rotate?(inputs)
        # puts "BEFORE position: #{player.position.to_h.inspect} scale: #{player.scale.to_h.inspect}, angle: #{player.angle}"
        angle_degrees = self.rotate_angle_degrees(inputs) % 360.0
        player.angle = angle_degrees
        scale_sign = (angle_degrees > 90 && angle_degrees < 270) ? -1 : 1
        player.scale.x = player.scale.x.abs * scale_sign
        player.scale.y = player.scale.y.abs * scale_sign
        # puts "AFTER position: #{player.position.to_h.inspect} scale: #{player.scale.to_h.inspect}, angle: #{player.angle}"
      end
      # puts "AFTER scale: #{player.scale.to_h.inspect}, angle: #{angle_degrees}"
      # Return rotation data
      return {
        rotation: {
          angle_degrees: angle_degrees
        }
      }
    end
  end
end
